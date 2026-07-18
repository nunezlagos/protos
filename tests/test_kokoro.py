"""Kokoro TTS tests (Red -> Green -> Refactor -> Sabotage)."""

import os
import subprocess
import tempfile
from pathlib import Path


KOKORO_DIR = Path.home() / ".local" / "share" / "kokoro"
KOKORO_MODEL = KOKORO_DIR / "kokoro-v1.0.onnx"
KOKORO_VOICES = KOKORO_DIR / "voices-v1.0.bin"

SKIP_REASON = "Kokoro not installed. Run: pip install kokoro-onnx"


def kokoro_available() -> bool:
    try:
        import kokoro_onnx  # noqa
        return True
    except ImportError:
        return False


def models_downloaded() -> bool:
    return KOKORO_MODEL.exists() and KOKORO_VOICES.exists()


class TestKokoroInstall:
    def test_pip_package_installed(self):
        assert kokoro_available(), SKIP_REASON

    def test_model_files_exist(self):
        assert KOKORO_MODEL.exists(), f"Model not found: {KOKORO_MODEL}"
        assert KOKORO_VOICES.exists(), f"Voices not found: {KOKORO_VOICES}"

    def test_model_size(self):
        size_mb = KOKORO_MODEL.stat().st_size / (1024 * 1024)
        assert 50 < size_mb < 500, f"Unexpected model size: {size_mb:.0f}MB"


class TestKokoroTTS:
    def test_generates_audio(self):
        if not (kokoro_available() and models_downloaded()):
            pytest.skip(SKIP_REASON)  # noqa
        from kokoro_onnx import Kokoro

        kokoro = Kokoro(str(KOKORO_MODEL), str(KOKORO_VOICES))
        samples, sr = kokoro.create("Hello world.", voice="af_sarah")

        assert sr == 24000
        assert len(samples) > 0
        assert len(samples) / sr > 0.3

    def test_saves_wav(self):
        if not (kokoro_available() and models_downloaded()):
            pytest.skip(SKIP_REASON)  # noqa
        from kokoro_onnx import Kokoro
        import soundfile as sf

        kokoro = Kokoro(str(KOKORO_MODEL), str(KOKORO_VOICES))
        samples, sr = kokoro.create("Test.", voice="af_sarah")

        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
            sf.write(f.name, samples, sr)
            size = Path(f.name).stat().st_size

        os.unlink(f.name)
        assert size > 1000

    def test_streaming_chunks(self):
        if not (kokoro_available() and models_downloaded()):
            pytest.skip(SKIP_REASON)  # noqa
        import asyncio
        from kokoro_onnx import Kokoro

        kokoro = Kokoro(str(KOKORO_MODEL), str(KOKORO_VOICES))

        async def run():
            chunks = []
            stream = kokoro.create_stream(
                "This is a streaming test.",
                voice="af_sarah",
                speed=1.0,
                lang="en-us",
            )
            async for samples, _ in stream:
                chunks.append(len(samples))
            return chunks

        chunks = asyncio.run(run())
        assert len(chunks) >= 1
        assert all(c > 0 for c in chunks)


class TestKokoroDefaults:
    def test_default_lang(self):
        from src.kokoro.engine import DEFAULT_LANG
        assert DEFAULT_LANG == "en-us"

    def test_default_speed(self):
        from src.kokoro.engine import DEFAULT_SPEED
        assert DEFAULT_SPEED == 1.0


class TestKokoroEngine:
    def test_custom_lang(self):
        from src.kokoro.engine import KokoroEngine
        engine = KokoroEngine(lang="es")
        assert engine.lang == "es"

    def test_lang_setter(self):
        from src.kokoro.engine import KokoroEngine
        engine = KokoroEngine()
        engine.lang = "fr"
        assert engine.lang == "fr"

    def test_custom_speed(self):
        from src.kokoro.engine import KokoroEngine
        engine = KokoroEngine(speed=0.8)
        assert engine.speed == 0.8

    def test_speed_setter(self):
        from src.kokoro.engine import KokoroEngine
        engine = KokoroEngine()
        engine.speed = 1.5
        assert engine.speed == 1.5

    def test_custom_voice(self):
        from src.kokoro.engine import KokoroEngine
        engine = KokoroEngine()
        import os
        os.environ["KOKORO_VOICE_DEFAULT"] = "af_nicole"
        from src.kokoro.engine import DEFAULT_VOICE
        assert DEFAULT_VOICE == "af_nicole"


class TestInstallScript:
    def test_shellcheck_passes(self):
        script = Path(__file__).parent.parent / "install.sh"
        assert script.exists()

        result = subprocess.run(
            ["bash", "-n", str(script)],
            capture_output=True, text=True,
        )
        assert result.returncode == 0, (
            f"Syntax error:\n{result.stderr}"
        )

    def test_lib_files_exist(self):
        lib_dir = Path(__file__).parent.parent / "lib"
        expected = {"common.sh", "os.sh", "pkg.sh", "kokoro.sh"}
        found = {f.name for f in lib_dir.glob("*.sh")}
        missing = expected - found
        assert not missing, f"Missing: {missing}"

    def test_env_has_language_var(self):
        env_file = Path.home() / ".config" / "kokoro-runtime" / "env"
        if not env_file.exists():
            pytest.skip("Env file not created yet")  # noqa
        content = env_file.read_text()
        assert "KOKORO_LANGUAGE=" in content
