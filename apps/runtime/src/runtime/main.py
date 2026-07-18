"""Voice loop: VAD record → Whisper STT → Gemini LLM → Kokoro TTS + barge-in."""

import signal
import sys
import threading

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


class VoiceLoop:
    def __init__(self):
        self._preprocessor = AudioPreprocessor()
        self._stt = WhisperSTT()
        self._llm = GeminiClient()
        self._tts = KokoroTTS()
        self._history = HistoryWindow()
        self._barge_in = BargeInLayer(self._preprocessor)
        self._running = True

    def _record_until_speech_end(self) -> np.ndarray:
        frames: list[np.ndarray] = []
        speech_active = False
        silence_frames = 0
        max_silence = int(0.8 * SAMPLE_RATE / BLOCK_SIZE)
        has_any_speech = False

        def callback(indata, _frames_count, _time_info, status):
            nonlocal speech_active, silence_frames, has_any_speech
            if not self._running:
                raise sd.CallbackAbort

            clean, prob = self._preprocessor.process(indata.flatten(), None)
            frames.append(clean.copy())

            if prob > 0.5:
                speech_active = True
                has_any_speech = True
                silence_frames = 0
            elif speech_active:
                silence_frames += 1
                if silence_frames >= max_silence:
                    raise sd.CallbackStop

        try:
            with sd.InputStream(
                samplerate=SAMPLE_RATE, channels=1, blocksize=BLOCK_SIZE, callback=callback
            ):
                while self._running:
                    sd.sleep(50)
        except sd.CallbackStop:
            pass

        if not has_any_speech or not frames:
            return np.array([], dtype=np.float32)
        return np.concatenate(frames).flatten()

    def _play_stream_with_bargein(self, tts_stream):
        playback_chunks: list[np.ndarray] = []
        barge_thread = None

        for chunk_idx, (samples, sr) in enumerate(tts_stream):
            if not self._running:
                break
            playback_chunks.append(samples)
            if chunk_idx == 0:
                playback_ref = np.concatenate(playback_chunks) if len(playback_chunks) > 1 else samples
                barge_thread = self._barge_in.start(playback_ref)
            sd.play(samples, sr)
            sd.wait()
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

        while self._running:
            try:
                audio = self._record_until_speech_end()
                if len(audio) < SAMPLE_RATE * 0.3:
                    continue

                text = self._stt.transcribe(audio).strip()
                if not text:
                    continue

                print(f"  Tu: {text}")
                self._history.append("user", text)

                response = self._llm.ask(text, self._history.format())
                print(f"  Protos: {response}")

                tts_stream = self._tts.speak_stream(response)
                interrupted = self._play_stream_with_bargein(tts_stream)

                if interrupted:
                    self._history.pop()
                else:
                    self._history.append("assistant", response)

            except KeyboardInterrupt:
                break
            except Exception as e:
                print(f"  Error: {e}")

        print("\nChau!")


def main():
    VoiceLoop().run()


if __name__ == "__main__":
    main()
