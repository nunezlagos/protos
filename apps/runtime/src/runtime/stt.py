from faster_whisper import WhisperModel

MODEL_SIZE = "tiny"
COMPUTE_TYPE = "int8"


class WhisperSTT:
    def __init__(self, model_size=MODEL_SIZE, compute_type=COMPUTE_TYPE):
        self._model = WhisperModel(model_size, device="cpu", compute_type=compute_type)

    def transcribe(self, audio) -> str:
        segments, _info = self._model.transcribe(audio, beam_size=1, language="es")
        return " ".join(seg.text for seg in segments)
