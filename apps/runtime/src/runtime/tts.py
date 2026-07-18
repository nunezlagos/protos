"""Kokoro TTS with streaming support."""

from kokoro.engine import KokoroEngine as _KokoroEngine


class KokoroTTS:
    def __init__(self):
        self._engine = _KokoroEngine()

    def speak(self, text: str):
        return self._engine.speak(text)

    def speak_stream(self, text: str):
        return self._engine.speak_stream(text)

    @property
    def lang(self):
        return self._engine.lang

    @lang.setter
    def lang(self, value):
        self._engine.lang = value
