"""Barge-in: monitor mic during TTS playback, interrupt on speech."""

import threading

import numpy as np
import sounddevice as sd

from .audio_processor import AudioPreprocessor

BLOCK_SIZE = 160


class BargeInLayer:
    def __init__(self, preprocessor: AudioPreprocessor):
        self._preprocessor = preprocessor
        self._stop = threading.Event()
        self._interrupted = False

    @property
    def interrupted(self) -> bool:
        return self._interrupted

    def start(self, playback_buffer: np.ndarray | None = None):
        self._stop.clear()
        self._interrupted = False
        t = threading.Thread(target=self._monitor, args=(playback_buffer,), daemon=True)
        t.start()
        return t

    def stop(self):
        self._stop.set()

    def _monitor(self, playback_buffer: np.ndarray | None):
        try:
            with sd.InputStream(
                samplerate=self._preprocessor.SAMPLE_RATE,
                channels=1,
                blocksize=BLOCK_SIZE,
            ) as stream:
                idx = 0
                while not self._stop.is_set():
                    chunk, _ = stream.read(BLOCK_SIZE)
                    ref = None
                    if playback_buffer is not None and idx < len(playback_buffer):
                        end = min(idx + BLOCK_SIZE, len(playback_buffer))
                        ref = playback_buffer[idx:end]
                        idx = end

                    _clean, prob = self._preprocessor.process(chunk.flatten(), ref)
                    if prob > 0.7:
                        self._interrupted = True
                        self._stop.set()
                        break
        except sd.PortAudioError:
            pass
