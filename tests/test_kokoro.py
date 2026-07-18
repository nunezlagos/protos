"""Tests para Kokoro TTS (TDD: Red → Green → Refactor → Sabotaje)."""

import os
import subprocess
import tempfile
from pathlib import Path


KOKORO_DIR = Path.home() / ".local" / "share" / "kokoro"
KOKORO_MODEL = KOKORO_DIR / "kokoro-v1.0.onnx"
KOKORO_VOICES = KOKORO_DIR / "voices-v1.0.bin"


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
        assert kokoro_available(), (
            "kokoro-onnx no instalado. "
            "Corré: pip install kokoro-onnx"
        )

    def test_model_files_exist(self):
        assert KOKORO_MODEL.exists(), (
            f"Modelo no encontrado: {KOKORO_MODEL}"
        )
        assert KOKORO_VOICES.exists(), (
            f"Voices no encontrado: {KOKORO_VOICES}"
        )

    def test_model_size(self):
        size_mb = KOKORO_MODEL.stat().st_size / (1024 * 1024)
        assert 50 < size_mb < 500, (
            f"Tamaño de modelo inesperado: {size_mb:.0f}MB"
        )


class TestKokoroTTS:
    def test_generates_audio(self):
        if not (kokoro_available() and models_downloaded()):
            pytest.skip("Kokoro no instalado")  # noqa
        from kokoro_onnx import Kokoro

        kokoro = Kokoro(str(KOKORO_MODEL), str(KOKORO_VOICES))
        samples, sr = kokoro.create("Hola mundo.", voice="af_sarah")

        assert sr == 24000
        assert len(samples) > 0
        assert len(samples) / sr > 0.3

    def test_saves_wav(self):
        if not (kokoro_available() and models_downloaded()):
            pytest.skip("Kokoro no instalado")  # noqa
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
            pytest.skip("Kokoro no instalado")  # noqa
        import asyncio
        from kokoro_onnx import Kokoro

        kokoro = Kokoro(str(KOKORO_MODEL), str(KOKORO_VOICES))

        async def run():
            chunks = []
            stream = kokoro.create_stream(
                "Esto es una prueba de streaming prolongado.",
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
        assert not missing, f"Faltan: {missing}"
