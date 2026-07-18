# lib/common.sh — helpers, logging, errores

export NC='\033[0m'
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export CYAN='\033[0;36m'

SUDO=""

log_info()  { printf "${CYAN}   ℹ️  %s${NC}\n" "$*"; }
log_ok()    { printf "${GREEN}   ✅ %s${NC}\n" "$*"; }
log_warn()  { printf "${YELLOW}   ⚠️  %s${NC}\n" "$*"; }
log_fail()  { printf "${RED}   ❌ %s${NC}\n" "$*"; exit 1; }
log_step()  { printf "\n${CYAN}━━━ %s ━━━${NC}\n" "$*"; }

require_cmd() {
  local cmd="$1"
  if ! command -v "${cmd}" &>/dev/null; then
    log_fail "${cmd} not found — install it and re-run"
  fi
}

require_sudo() {
  if [ "${EUID}" -eq 0 ]; then
    SUDO=""
    return
  fi
  command -v sudo &>/dev/null || log_fail "sudo not found. Run as root or install sudo."
  SUDO="sudo"
}
