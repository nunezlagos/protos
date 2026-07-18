# lib/kokoro.sh — Kokoro TTS install helpers

KOKORO_DIR="${HOME}/.local/share/kokoro"
KOKORO_TAG="v1.0"
KOKORO_BASE_URL="https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-${KOKORO_TAG}"

kokoro_install_system_deps() {
  local manager="$1"

  case "${manager}" in
    pacman) echo "espeak-ng python python-pip curl" ;;
    apt)    echo "espeak-ng python3 python3-pip curl" ;;
    dnf)    echo "espeak-ng python3 python3-pip curl" ;;
    zypper) echo "espeak-ng python3 python3-pip curl" ;;
    apk)    echo "espeak-ng python3 py3-pip curl" ;;
  esac
}

kokoro_download_models() {
  mkdir -p "${KOKORO_DIR}"

  local onnx="${KOKORO_DIR}/kokoro-${KOKORO_TAG}.onnx"
  local voices="${KOKORO_DIR}/voices-${KOKORO_TAG}.bin"

  if [ -f "${onnx}" ] && [ -f "${voices}" ]; then
    log_ok "Models already downloaded in ${KOKORO_DIR}"
    return
  fi

  log_info "Downloading models from GitHub Releases..."
  curl -fSL# -o "${onnx}"   "${KOKORO_BASE_URL}/kokoro-${KOKORO_TAG}.onnx"
  curl -fSL# -o "${voices}" "${KOKORO_BASE_URL}/voices-${KOKORO_TAG}.bin"

  log_ok "Models downloaded to ${KOKORO_DIR}"
}

kokoro_install_python_pkg() {
  log_info "Installing kokoro-onnx..."

  pip install -U --quiet kokoro-onnx sounddevice soundfile 2>&1 | tail -1

  log_ok "kokoro-onnx installed"
}

kokoro_test() {
  log_info "Generating test audio..."

  local lang="${KOKORO_LANGUAGE:-es}"
  local text
  case "${lang}" in
    es*) text="Hola, esto es una prueba de Kokoro TTS." ;;
    pt*) text="Olá, isto é um teste do Kokoro TTS." ;;
    fr*) text="Bonjour, ceci est un test de Kokoro TTS." ;;
    it*) text="Ciao, questo è un test di Kokoro TTS." ;;
    ja*) text="こんにちは、これはKokoro TTSのテストです。" ;;
    zh*) text="你好，这是Kokoro TTS的测试。" ;;
    hi*) text="नमस्ते, यह Kokoro TTS का परीक्षण है।" ;;
    *)   text="Hello, this is a Kokoro TTS test." ;;
  esac

  python3 - <<-PYEOF 2>&1
from kokoro_onnx import Kokoro
import soundfile as sf

kokoro = Kokoro(
    '${KOKORO_DIR}/kokoro-${KOKORO_TAG}.onnx',
    '${KOKORO_DIR}/voices-${KOKORO_TAG}.bin'
)
samples, sr = kokoro.create('${text}', voice='af_sarah')
sf.write('/tmp/kokoro-test.wav', samples, sr)
print(f"   OK Audio: /tmp/kokoro-test.wav ({len(samples)/sr:.1f}s @ {sr}Hz)")
PYEOF
}

kokoro_env_path() {
  printf "%s/.config/kokoro-runtime/env" "${HOME}"
}

kokoro_write_env() {
  local env_path
  env_path="$(kokoro_env_path)"
  mkdir -p "$(dirname "${env_path}")"

  if [ -f "${env_path}" ]; then
    log_info "Env already exists: ${env_path}"
    return
  fi

  cat > "${env_path}" <<-EOF
# Kokoro TTS configuration
# Uncomment and edit to override defaults

KOKORO_MODEL="${KOKORO_DIR}/kokoro-${KOKORO_TAG}.onnx"
KOKORO_VOICES="${KOKORO_DIR}/voices-${KOKORO_TAG}.bin"

# Voice: af_sarah, af_nicole, af_bella, af_heart, am_michael, am_fenrir, etc.
KOKORO_VOICE_DEFAULT="am_fenrir"

# Language: en-us, en-gb, es, fr, pt, it, ja, zh, hi, ko
KOKORO_LANGUAGE="es"

# Speech speed: 0.5 (slow) to 2.0 (fast), default 1.0
# KOKORO_SPEED="1.0"
EOF

  log_ok "Env created: ${env_path}"
}
