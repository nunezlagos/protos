"""Wrapper alrededor de kokoro-onnx para el runtime."""

import os
from pathlib import Path


KOKORO_DIR = Path.home() / ".local" / "share" / "kokoro"
KOKORO_MODEL = os.getenv("KOKORO_MODEL", str(KOKORO_DIR / "kokoro-v1.0.onnx"))
KOKORO_VOICES = os.getenv("KOKORO_VOICES", str(KOKORO_DIR / "voices-v1.0.bin"))
DEFAULT_VOICE = os.getenv("KOKORO_VOICE_DEFAULT", "af_sarah")


class KokoroEngine:
    def __init__(self, model_path=None, voices_path=None):
        from kokoro_onnx import Kokoro as KokoroLib

        self._model_path = model_path or KOKORO_MODEL
        self._voices_path = voices_path or KOKORO_VOICES
        self._kokoro = KokoroLib(self._model_path, self._voices_path)

    def speak(self, text, voice=None):
        samples, sample_rate = self._kokoro.create(
            text,
            voice=voice or DEFAULT_VOICE,
            speed=1.0,
        )
        return samples, sample_rate

    def speak_stream(self, text, voice=None):
        return self._kokoro.create_stream(
            text,
            voice=voice or DEFAULT_VOICE,
            speed=1.0,
            lang="en-us",
        )
