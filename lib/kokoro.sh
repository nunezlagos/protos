# lib/kokoro.sh — instalación de Kokoro TTS (modelos + pip)

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
    log_ok "Modelos ya descargados en ${KOKORO_DIR}"
    return
  fi

  log_info "Descargando modelos desde GitHub Releases..."
  curl -fSL# -o "${onnx}"   "${KOKORO_BASE_URL}/kokoro-${KOKORO_TAG}.onnx"
  curl -fSL# -o "${voices}" "${KOKORO_BASE_URL}/voices-${KOKORO_TAG}.bin"

  log_ok "Modelos descargados en ${KOKORO_DIR}"
}

kokoro_install_python_pkg() {
  log_info "Instalando kokoro-onnx..."

  pip install -U --quiet kokoro-onnx sounddevice soundfile 2>&1 | tail -1

  log_ok "kokoro-onnx instalado"
}

kokoro_test() {
  log_info "Generando audio de prueba..."

  python3 - <<-PYEOF 2>&1
from kokoro_onnx import Kokoro
import soundfile as sf

kokoro = Kokoro(
    '${KOKORO_DIR}/kokoro-${KOKORO_TAG}.onnx',
    '${KOKORO_DIR}/voices-${KOKORO_TAG}.bin'
)
samples, sr = kokoro.create('Hola, todo funciona correctamente.', voice='af_sarah')
sf.write('/tmp/kokoro-test.wav', samples, sr)
print(f"   ✅ Audio: /tmp/kokoro-test.wav ({len(samples)/sr:.1f}s @ {sr}Hz)")
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
    log_info "Env ya existe: ${env_path}"
    return
  fi

  cat > "${env_path}" <<-EOF
KOKORO_MODEL="${KOKORO_DIR}/kokoro-${KOKORO_TAG}.onnx"
KOKORO_VOICES="${KOKORO_DIR}/voices-${KOKORO_TAG}.bin"
KOKORO_VOICE_DEFAULT="af_sarah"
EOF

  log_ok "Env creado: ${env_path}"
}
