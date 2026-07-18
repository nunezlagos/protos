#!/usr/bin/env bash
# install.sh — Protos: Kokoro TTS installer (curl | bash friendly)
# Usage: curl -fsSL https://raw.githubusercontent.com/nunezlagos/protos/main/install.sh | bash
set -euo pipefail

# ─── Config ─────────────────────────────────────────────────────────
KOKORO_DIR="${HOME}/.local/share/kokoro"
KOKORO_TAG="v1.0"
KOKORO_BASE_URL="https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-${KOKORO_TAG}"

# ─── ANSI colors ────────────────────────────────────────────────────
NC='\033[0m'; RED='\033[0;31m'; GREEN='\033[0;32m'
YELLOW='\033[1;33m'; CYAN='\033[0;36m'

log_info()  { printf "${CYAN}   i %s${NC}\n" "$*"; }
log_ok()    { printf "${GREEN}   v %s${NC}\n" "$*"; }
log_warn()  { printf "${YELLOW}   ! %s${NC}\n" "$*"; }
log_fail()  { printf "${RED}   x %s${NC}\n" "$*"; exit 1; }
log_step()  { printf "\n${CYAN}--- %s ---${NC}\n" "$*"; }

# ─── OS detection ───────────────────────────────────────────────────
os_id() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release; printf "%s" "${ID}"
  else printf "unknown"; fi
}

os_pretty_name() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release; printf "%s" "${PRETTY_NAME:-${ID}}"
  else printf "unknown"; fi
}

os_pkg_manager() {
  local id; id="$(os_id)"
  case "${id}" in
    arch|manjaro|endeavouros)  printf "pacman" ;;
    debian|ubuntu|linuxmint|pop) printf "apt" ;;
    fedora)                    printf "dnf" ;;
    opensuse*|suse)            printf "zypper" ;;
    alpine)                    printf "apk" ;;
    *)
      if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "${ID_LIKE}" in
          *arch*)   printf "pacman" ;;
          *debian*) printf "apt" ;;
          *fedora*) printf "dnf" ;;
          *)        printf "unknown" ;;
        esac
      else printf "unknown"; fi
      ;;
  esac
}

# ─── Package install ────────────────────────────────────────────────
pkg_install() {
  local m="$1"; shift
  case "${m}" in
    pacman) sudo pacman -S --needed --noconfirm "$@" >/dev/null 2>&1 ;;
    apt)    sudo apt update -qq 2>/dev/null; sudo apt install -y -qq "$@" >/dev/null 2>&1 ;;
    dnf)    sudo dnf install -y "$@" >/dev/null 2>&1 ;;
    zypper) sudo zypper --non-interactive install "$@" >/dev/null 2>&1 ;;
    apk)    sudo apk add --no-cache "$@" >/dev/null 2>&1 ;;
    *)      log_fail "Package manager '${m}' not supported" ;;
  esac
}

# ─── Steps ──────────────────────────────────────────────────────────
step_system() {
  log_step "System dependencies"
  local pm; pm="$(os_pkg_manager)"
  log_info "OS: $(os_pretty_name)"
  log_info "Package manager: ${pm}"

  local deps
  case "${pm}" in
    pacman) deps="espeak-ng python python-pip curl" ;;
    apt)    deps="espeak-ng python3 python3-pip curl" ;;
    dnf)    deps="espeak-ng python3 python3-pip curl" ;;
    zypper) deps="espeak-ng python3 python3-pip curl" ;;
    apk)    deps="espeak-ng python3 py3-pip curl" ;;
  esac

  pkg_install "${pm}" ${deps}
  log_ok "System dependencies installed"
}

step_validate() {
  log_step "Environment validation"
  for cmd in python3 pip3 curl; do
    command -v "${cmd}" &>/dev/null || log_fail "${cmd} not found"
  done
  log_ok "Environment valid"
}

step_models() {
  log_step "Kokoro models"
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

step_python() {
  log_step "Python package"
  log_info "Installing kokoro-onnx..."
  pip install -U --quiet kokoro-onnx sounddevice soundfile
  log_ok "kokoro-onnx installed"
}

step_env() {
  log_step "Environment config"
  local env_path="${HOME}/.config/kokoro-runtime/env"
  mkdir -p "$(dirname "${env_path}")"

  cat > "${env_path}" <<-EOF
# Kokoro TTS configuration
KOKORO_MODEL="${KOKORO_DIR}/kokoro-${KOKORO_TAG}.onnx"
KOKORO_VOICES="${KOKORO_DIR}/voices-${KOKORO_TAG}.bin"
KOKORO_VOICE_DEFAULT="am_fenrir"
KOKORO_LANGUAGE="es"
KOKORO_SPEED="1.0"
EOF

  log_ok "Env updated: ${env_path}"
}

step_test() {
  log_step "Generation test"
  log_info "Generating test audio..."
  local lang="${KOKORO_LANGUAGE:-es}"
  local text
  case "${lang}" in
    es*) text="Hola, esto es una prueba de Kokoro TTS." ;;
    pt*) text="Ola, isto e um teste do Kokoro TTS." ;;
    fr*) text="Bonjour, ceci est un test de Kokoro TTS." ;;
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
  log_ok "Test audio generated at /tmp/kokoro-test.wav"
}

# ─── Main ───────────────────────────────────────────────────────────
main() {
  cat <<-EOF
$(os_pretty_name) — Kokoro TTS installer
EOF

  step_system
  step_validate
  step_models
  step_python
  step_env
  step_test

  cat <<-EOF

  Done.
  OS:      $(os_pretty_name)
  Models:  ${KOKORO_DIR}
  Env:     ${HOME}/.config/kokoro-runtime/env
  Audio:   /tmp/kokoro-test.wav
EOF
}

main "$@"
