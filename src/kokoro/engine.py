import os
from pathlib import Path


KOKORO_DIR = Path.home() / ".local" / "share" / "kokoro"
KOKORO_MODEL = os.getenv("KOKORO_MODEL", str(KOKORO_DIR / "kokoro-v1.0.onnx"))
KOKORO_VOICES = os.getenv("KOKORO_VOICES", str(KOKORO_DIR / "voices-v1.0.bin"))
DEFAULT_VOICE = os.getenv("KOKORO_VOICE_DEFAULT", "af_sarah")
DEFAULT_LANG = os.getenv("KOKORO_LANGUAGE", "en-us")


class KokoroEngine:
    def __init__(self, model_path=None, voices_path=None, lang=None):
        from kokoro_onnx import Kokoro as KokoroLib

        self._model_path = model_path or KOKORO_MODEL
        self._voices_path = voices_path or KOKORO_VOICES
        self._lang = lang or DEFAULT_LANG
        self._kokoro = KokoroLib(self._model_path, self._voices_path)

    @property
    def lang(self):
        return self._lang

    @lang.setter
    def lang(self, value):
        self._lang = value

    def speak(self, text, voice=None, lang=None):
        samples, sample_rate = self._kokoro.create(
            text,
            voice=voice or DEFAULT_VOICE,
            speed=1.0,
        )
        return samples, sample_rate

    def speak_stream(self, text, voice=None, lang=None):
        return self._kokoro.create_stream(
            text,
            voice=voice or DEFAULT_VOICE,
            speed=1.0,
            lang=lang or self._lang,
        )
