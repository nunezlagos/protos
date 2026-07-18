#!/usr/bin/env bash
# install.sh — Protos all-in-one installer
#   curl | bash:  clones + installs everything
#   ./install.sh: installs from current repo
set -euo pipefail

NC='\033[0m'; RED='\033[0;31m'; GREEN='\033[0;32m'
YELLOW='\033[1;33m'; CYAN='\033[0;36m'

log_info()  { printf "${CYAN}   i %s${NC}\n" "$*"; }
log_ok()    { printf "${GREEN}   v %s${NC}\n" "$*"; }
log_warn()  { printf "${YELLOW}   ! %s${NC}\n" "$*"; }
log_fail()  { printf "${RED}   x %s${NC}\n" "$*"; exit 1; }
log_step()  { printf "\n${CYAN}--- %s ---${NC}\n" "$*"; }

# ─── OS helpers ─────────────────────────────────────────────────────
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

# ─── Repo setup ─────────────────────────────────────────────────────
REPO_DIR=""
clone_or_cd() {
  if [ -f "Makefile" ] && [ -f "install.sh" ] && [ -d "libs" ]; then
    # Already in the repo
    REPO_DIR="$(pwd)"
    log_ok "Using current directory: ${REPO_DIR}"
    return
  fi

  local target="${HOME}/protos"
  if [ -d "${target}" ]; then
    log_info "Protos already cloned in ${target}"
  else
    log_info "Cloning protos into ${target}..."
    git clone https://github.com/nunezlagos/protos.git "${target}"
  fi

  REPO_DIR="${target}"
  cd "${REPO_DIR}"
}

# ─── Steps ──────────────────────────────────────────────────────────
step_system_deps() {
  log_step "System dependencies"
  local pm; pm="$(os_pkg_manager)"
  log_info "OS: $(os_pretty_name)  (${pm})"

  local deps
  case "${pm}" in
    pacman) deps="espeak-ng python python-pip curl git" ;;
    apt)    deps="espeak-ng python3 python3-pip curl git" ;;
    dnf)    deps="espeak-ng python3 python3-pip curl git" ;;
    zypper) deps="espeak-ng python3 python3-pip curl git" ;;
    apk)    deps="espeak-ng python3 py3-pip curl git" ;;
  esac

  pkg_install "${pm}" ${deps}
  log_ok "System dependencies installed"
}

step_kokoro_models() {
  log_step "Kokoro models"
  local dir="${HOME}/.local/share/kokoro"
  mkdir -p "${dir}"

  local onnx="${dir}/kokoro-v1.0.onnx"
  local voices="${dir}/voices-v1.0.bin"

  if [ -f "${onnx}" ] && [ -f "${voices}" ]; then
    log_ok "Models already downloaded in ${dir}"
    return
  fi

  local base="https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0"
  log_info "Downloading models (~170MB)..."
  curl -fSL# -o "${onnx}"   "${base}/kokoro-v1.0.onnx"
  curl -fSL# -o "${voices}" "${base}/voices-v1.0.bin"
  log_ok "Models downloaded to ${dir}"
}

step_kokoro_env() {
  log_step "Kokoro env config"
  local env_path="${HOME}/.config/kokoro-runtime/env"
  mkdir -p "$(dirname "${env_path}")"

  cat > "${env_path}" <<-EOF
KOKORO_MODEL=${HOME}/.local/share/kokoro/kokoro-v1.0.onnx
KOKORO_VOICES=${HOME}/.local/share/kokoro/voices-v1.0.bin
KOKORO_VOICE_DEFAULT=am_fenrir
KOKORO_LANGUAGE=es
KOKORO_SPEED=1.0
EOF
  log_ok "Env updated: ${env_path}"
}

step_project_env() {
  log_step "Project env"
  if [ -f ".env" ]; then
    log_ok ".env already exists — keeping it"
    return
  fi
  if [ -f ".env.example" ]; then
    cp .env.example .env
    log_info "Created .env from .env.example"
    log_warn "Edit .env and set your API_LLM key before running"
  fi
}

step_python_packages() {
  log_step "Python packages"

  log_info "Installing kokoro-onnx..."
  pip install -U --quiet kokoro-onnx sounddevice soundfile

  log_info "Installing protos packages..."
  pip install -e libs/kokoro
  pip install -e apps/runtime

  log_ok "All Python packages installed"
}

step_kokoro_test() {
  log_step "Kokoro test"
  log_info "Generating test audio..."
  python3 - <<-PYEOF 2>&1
from kokoro_onnx import Kokoro
import soundfile as sf
kokoro = Kokoro(
    '${HOME}/.local/share/kokoro/kokoro-v1.0.onnx',
    '${HOME}/.local/share/kokoro/voices-v1.0.bin'
)
samples, sr = kokoro.create('Hola, esto es una prueba de Kokoro TTS.', voice='af_sarah')
sf.write('/tmp/kokoro-test.wav', samples, sr)
print(f"   OK Audio: /tmp/kokoro-test.wav ({len(samples)/sr:.1f}s @ {sr}Hz)")
PYEOF
  log_ok "Test audio generated: /tmp/kokoro-test.wav"
}

# ─── Main ───────────────────────────────────────────────────────────
main() {
  cat <<-EOF

  Protos — Voice runtime installer
  $(os_pretty_name)

EOF

  clone_or_cd

  step_system_deps
  step_kokoro_models
  step_kokoro_env
  step_project_env
  step_python_packages
  step_kokoro_test

  cat <<-EOF

  ──────────────────────────────────────
  Installed successfully
  ──────────────────────────────────────
  Location: ${REPO_DIR}
  Models:   ${HOME}/.local/share/kokoro
  Test:     /tmp/kokoro-test.wav

  Next:
    cd ${REPO_DIR}
    vim .env      # set API_LLM
    make run      # start voice loop
  ──────────────────────────────────────
EOF
}

main "$@"
