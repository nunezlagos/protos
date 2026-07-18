import os

from faster_whisper import WhisperModel

MODEL_SIZE = os.getenv("PROTOS_WHISPER_MODEL", "base")
COMPUTE_TYPE = os.getenv("PROTOS_WHISPER_COMPUTE", "int8")
WHISPER_LANG = os.getenv("PROTOS_WHISPER_LANG", "es")


class WhisperSTT:
    def __init__(self, model_size=MODEL_SIZE, compute_type=COMPUTE_TYPE):
        self._model = WhisperModel(model_size, device="cpu", compute_type=compute_type)

    def transcribe(self, audio) -> str:
        segments, _info = self._model.transcribe(audio, beam_size=5, language=WHISPER_LANG, vad_filter=True)
        return " ".join(seg.text for seg in segments)
