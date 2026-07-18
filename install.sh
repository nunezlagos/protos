#!/usr/bin/env bash
# install.sh — Protos all-in-one installer
#   curl | bash:  clones + installs everything
#   ./install.sh: installs from current repo
set -euo pipefail

NC='\033[0m'; RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'

log()   { printf "  %s\n" "$*"; }
ok()    { printf "${GREEN}  ✓ %s${NC}\n" "$*"; }
info()  { printf "${CYAN}  · %s${NC}\n" "$*"; }
fail()  { printf "${RED}  ✗ %s${NC}\n" "$*"; exit 1; }

spinner() {
  local pid=$1 msg="$2" s="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏" i=0
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r  ${CYAN}%s${NC} %s" "${s:i++%${#s}:1}" "$msg"
    sleep 0.1
  done
  wait "$pid"; local rc=$?
  [ "$rc" -eq 0 ] && printf "\r  ${GREEN}✓${NC} %s\n" "$msg" || printf "\r  ${RED}✗${NC} %s\n" "$msg"
  return "$rc"
}

os_id()           { . /etc/os-release &>/dev/null && printf "%s" "${ID}" || printf "unknown"; }
os_pretty_name()  { . /etc/os-release &>/dev/null && printf "%s" "${PRETTY_NAME:-${ID}}" || printf "unknown"; }
os_pkg_manager() {
  local id; id="$(os_id)"
  case "${id}" in
    arch|manjaro|endeavouros)  printf "pacman" ;;
    debian|ubuntu|linuxmint|pop) printf "apt" ;;
    fedora)                    printf "dnf" ;;
    opensuse*|suse)            printf "zypper" ;;
    alpine)                    printf "apk" ;;
    *)
      . /etc/os-release 2>/dev/null
      case "${ID_LIKE}" in *arch*) printf "pacman" ;; *debian*) printf "apt" ;; *fedora*) printf "dnf" ;; *) printf "unknown" ;; esac ;;
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
  esac
}

REPO_DIR=""
PYTHON="python3"; PIP="pip3"; VENV_DIR=""

clone_or_cd() {
  if [ -f "Makefile" ] && [ -f "install.sh" ] && [ -d "libs" ]; then
    REPO_DIR="$(pwd)"; return
  fi
  local t="${HOME}/protos"
  [ -d "${t}" ] || git clone https://github.com/nunezlagos/protos.git "${t}"
  REPO_DIR="${t}"; cd "${REPO_DIR}"
}

ensure_venv() {
  VENV_DIR="${REPO_DIR}/venv"

  # Try system python3 first
  python3 -m pip install --dry-run kokoro-onnx --quiet 2>/dev/null && {
    python3 -m pip install --dry-run --quiet 2>/dev/null && return
    python3 -m pip install --dry-run --break-system-packages --quiet 2>/dev/null && { PIP="python3 -m pip --break-system-packages"; return; }
    info "Creating virtualenv..."
    python3 -m venv "${VENV_DIR}" --clear
    PIP="${VENV_DIR}/bin/pip"; PYTHON="${VENV_DIR}/bin/python"
    return
  }

  # System python can't install kokoro-onnx — scan for compatible versions
  local alt
  for alt in python3.12 python3.11 python3.10 python3.13; do
    command -v "$alt" &>/dev/null || continue
    info "Using ${alt} for compatibility..."
    $alt -m venv "${VENV_DIR}" --clear
    PIP="${VENV_DIR}/bin/pip"; PYTHON="${VENV_DIR}/bin/python"
    return
  done

  # Auto-install based on distro
  local pm; pm="$(os_pkg_manager)"
  case "${pm}" in
    pacman)
      if ! command -v yay &>/dev/null; then
        info "Installing yay (AUR helper)..."
        sudo pacman -S --needed --noconfirm git base-devel >/dev/null 2>&1
        git clone --depth=1 https://aur.archlinux.org/yay.git /tmp/yay-install 2>/dev/null
        (cd /tmp/yay-install && makepkg -si --noconfirm) >/dev/null 2>&1
        rm -rf /tmp/yay-install
      fi
      info "Installing python312..."
      yay -S --noconfirm python312
      python3.12 -m venv "${VENV_DIR}" --clear
      PIP="${VENV_DIR}/bin/pip"; PYTHON="${VENV_DIR}/bin/python"
      return
      ;;
    apt)
      sudo apt install -y python3.12 python3.12-venv 2>/dev/null && {
        python3.12 -m venv "${VENV_DIR}" --clear
        PIP="${VENV_DIR}/bin/pip"; PYTHON="${VENV_DIR}/bin/python"
        return
      }
      ;;
    dnf)
      sudo dnf install -y python3.12 2>/dev/null && {
        python3.12 -m venv "${VENV_DIR}" --clear
        PIP="${VENV_DIR}/bin/pip"; PYTHON="${VENV_DIR}/bin/python"
        return
      }
      ;;
  esac

  fail "No compatible Python found (kokoro-onnx needs 3.10-3.13). Install python3.12 and re-run."
}

main() {
  clone_or_cd; ensure_venv

  log "$(os_pretty_name) · Protos installer"

  local pm; pm="$(os_pkg_manager)"
  local deps
  case "${pm}" in
    pacman) deps="espeak-ng python python-pip curl git" ;;
    apt|dnf|zypper) deps="espeak-ng python3 python3-pip curl git" ;;
    apk) deps="espeak-ng python3 py3-pip curl git" ;;
  esac
  pkg_install "${pm}" ${deps}
  ok "System deps"

  local dir="${HOME}/.local/share/kokoro"
  mkdir -p "${dir}"
  if [ ! -f "${dir}/kokoro-v1.0.onnx" ] || [ ! -f "${dir}/voices-v1.0.bin" ]; then
    local b="https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0"
    curl -fSL# -o "${dir}/kokoro-v1.0.onnx" "${b}/kokoro-v1.0.onnx"
    curl -fSL# -o "${dir}/voices-v1.0.bin" "${b}/voices-v1.0.bin"
  fi
  ok "Kokoro models"

  mkdir -p "${HOME}/.config/kokoro-runtime"
  cat > "${HOME}/.config/kokoro-runtime/env" <<-EOF
KOKORO_MODEL=${dir}/kokoro-v1.0.onnx
KOKORO_VOICES=${dir}/voices-v1.0.bin
KOKORO_VOICE_DEFAULT=am_fenrir
KOKORO_LANGUAGE=es
KOKORO_SPEED=1.0
EOF

  [ -f ".env" ] || { cp .env.example .env; info "Created .env — set API_LLM before running"; }
  ok "Config"

  { ${PIP} install -U --quiet kokoro-onnx sounddevice soundfile && ${PIP} install -e libs/kokoro apps/runtime; } &
  spinner $! "Installing Python packages"

  ${PYTHON} -c "
from kokoro_onnx import Kokoro
import soundfile as sf
k = Kokoro('${dir}/kokoro-v1.0.onnx', '${dir}/voices-v1.0.bin')
s, r = k.create('Hola, esto es una prueba.', voice='af_sarah')
sf.write('/tmp/kokoro-test.wav', s, r)
print(f'  ✓ Test audio: /tmp/kokoro-test.wav ({len(s)/r:.1f}s)')" 2>&1 | tail -1

  local s=""
  [ -n "${VENV_DIR}" ] && [ -f "${VENV_DIR}/bin/activate" ] && s="source ${VENV_DIR}/bin/activate && "
  echo
  log "Done — cd ${REPO_DIR} && ${s}make run"
}

main "$@"
