"""Voice loop: VAD record → Whisper STT → Gemini LLM → Kokoro TTS + barge-in."""

import os
import signal
import sys
import threading
import time
from dotenv import load_dotenv

load_dotenv()

import numpy as np
import sounddevice as sd

from .audio_processor import AudioPreprocessor
from .barge_in import BargeInLayer
from .history import HistoryWindow
from .llm import GeminiClient
from .stt import WhisperSTT
from .tts import KokoroTTS

SAMPLE_RATE = AudioPreprocessor.SAMPLE_RATE
BLOCK_SIZE = 320
VAD_THRESHOLD = float(os.getenv("PROTOS_VAD_THRESHOLD", "0.08"))
MAX_RECORD_SEC = float(os.getenv("PROTOS_MAX_RECORD_SEC", "10"))
INPUT_DEVICE = int(os.getenv("PROTOS_INPUT_DEVICE", "-1"))
OUTPUT_DEVICE = int(os.getenv("PROTOS_OUTPUT_DEVICE", "-1"))


def _list_devices():
    print("  Input devices:")
    for d in sd.query_devices():
        if d["max_input_channels"] > 0:
            print(f"    {d['index']}: {d['name']}")
    print("  Output devices:")
    for d in sd.query_devices():
        if d["max_output_channels"] > 0:
            print(f"    {d['index']}: {d['name']}")
    print(f"  Default input: {sd.default.device[0]}")
    print(f"  Default output: {sd.default.device[1]}")


class VoiceLoop:
    def __init__(self):
        self._preprocessor = AudioPreprocessor()
        self._stt = WhisperSTT()
        self._llm = GeminiClient()
        self._tts = KokoroTTS()
        self._history = HistoryWindow()
        self._barge_in = BargeInLayer(self._preprocessor)
        self._running = True
        self._show_vad = True

    def _record_until_speech_end(self) -> np.ndarray:
        frames: list[np.ndarray] = []
        speech_active = False
        silence_frames = 0
        max_silence = int(0.8 * SAMPLE_RATE / BLOCK_SIZE)
        has_any_speech = False
        max_total = int(MAX_RECORD_SEC * SAMPLE_RATE / BLOCK_SIZE)
        total_frames = 0

        def callback(indata, _frames_count, _time_info, status):
            nonlocal speech_active, silence_frames, has_any_speech, total_frames
            if not self._running:
                raise sd.CallbackAbort

            clean, prob = self._preprocessor.process(indata.flatten(), None)
            frames.append(clean.copy())
            total_frames += 1

            rms = np.sqrt(np.mean(indata.flatten() ** 2))

            if prob > VAD_THRESHOLD or rms > 0.02:
                speech_active = True
                has_any_speech = True
                silence_frames = 0
            elif speech_active:
                silence_frames += 1
                if silence_frames >= max_silence:
                    raise sd.CallbackStop

            if total_frames >= max_total:
                raise sd.CallbackStop

            if self._show_vad:
                if prob > 0.05:
                    bar = "█" * int(prob * 20)
                    print(f"\r  VAD: {prob:.2f} {bar}", end="", flush=True)
                elif not speech_active:
                    print("\r  Escuchando...   ", end="", flush=True)

        print("  Escuchando...", end="", flush=True)
        input_kwargs = dict(samplerate=SAMPLE_RATE, channels=1, blocksize=BLOCK_SIZE, callback=callback)
        if INPUT_DEVICE >= 0:
            input_kwargs["device"] = INPUT_DEVICE
        try:
            with sd.InputStream(**input_kwargs):
                while self._running:
                    sd.sleep(50)
        except sd.CallbackStop:
            pass
        print()

        dur = len(frames) * BLOCK_SIZE / SAMPLE_RATE if frames else 0
        if not has_any_speech or not frames:
            print(f"  (no speech detected, {dur:.1f}s)")
            return np.array([], dtype=np.float32)
        print(f"  (speech: {dur:.1f}s)")
        return np.concatenate(frames).flatten()

    def _play_stream_with_bargein(self, tts_stream):
        playback_chunks: list[np.ndarray] = []
        barge_thread = None

        for chunk_idx, (samples, sr) in enumerate(tts_stream):
            if not self._running:
                break
            playback_chunks.append(samples)
            if chunk_idx == 0:
                print(f"  playback ref: {len(samples)} samples")
                playback_ref = np.concatenate(playback_chunks) if len(playback_chunks) > 1 else samples
                barge_thread = self._barge_in.start(playback_ref)
            sd.play(samples, sr, device=OUTPUT_DEVICE if OUTPUT_DEVICE >= 0 else None)
            t = threading.Thread(target=sd.wait)
            t.start()
            t.join(timeout=10)
            if t.is_alive():
                print("  (audio timeout, skipping)")
                sd.stop()
                break
            if self._barge_in.interrupted:
                sd.stop()
                break

        if barge_thread is not None:
            self._barge_in.stop()
            barge_thread.join(timeout=1)

        return self._barge_in.interrupted

    def run(self):
        def handle_sigint(_sig, _frame):
            self._running = False

        signal.signal(signal.SIGINT, handle_sigint)

        print("Protos runtime iniciado. Habla cuando quieras (Ctrl+C para salir).")
        print("-" * 50)
        print("Audio devices:")
        _list_devices()
        print(f"  VAD threshold: {VAD_THRESHOLD}")
        print(f"  Max record: {MAX_RECORD_SEC}s")
        print()

        while self._running:
            try:
                audio = self._record_until_speech_end()
                if len(audio) < SAMPLE_RATE * 0.3:
                    continue

                print("  Transcribiendo...", end=" ", flush=True)
                text = self._stt.transcribe(audio).strip()
                if not text:
                    print("(silencio)")
                    continue
                print(text)
                self._history.append("user", text)

                print("  Consultando Gemini...", end=" ", flush=True)
                response = self._llm.ask(text, self._history.format())
                print(response)

                print("  Generando TTS...", end=" ", flush=True)
                tts_stream = self._tts.speak_stream(response)
                print("OK")

                interrupted = self._play_stream_with_bargein(tts_stream)

                if interrupted:
                    self._history.pop()
                else:
                    self._history.append("assistant", response)

            except KeyboardInterrupt:
                break
            except Exception as e:
                print(f"\n  Error: {e}")
                import traceback
                traceback.print_exc()

        print("\nChau!")


def main():
    VoiceLoop().run()


if __name__ == "__main__":
    main()
