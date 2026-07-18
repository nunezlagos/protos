"""WebRTC AudioProcessing: AEC + Noise Suppression + AGC + VAD."""

import numpy as np
from pywebrtc_audio import AudioProcessor as _AudioProcessor


class AudioPreprocessor:
    SAMPLE_RATE = 16000
    SPEECH_THRESHOLD = 0.5

    def __init__(self):
        self._ap = _AudioProcessor(
            sample_rate=self.SAMPLE_RATE,
            noise_suppression=True,
            echo_cancellation=True,
            auto_gain_control=True,
        )

    def process(
        self, mic_audio: np.ndarray, playback_ref: np.ndarray | None = None
    ) -> tuple[np.ndarray, float]:
        far = playback_ref if playback_ref is not None else np.zeros_like(mic_audio)
        clean = self._ap.process(mic_audio, far)
        return clean, self._ap.speech_probability

    @property
    def speech_probability(self) -> float:
        return self._ap.speech_probability

    def is_speech(self) -> bool:
        return self._ap.speech_probability >= self.SPEECH_THRESHOLD
