#!/usr/bin/env bash
# install.sh — Kokoro TTS installer entrypoint
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ─── Load modules ──────────────────────────────────────────────────
. "${SCRIPT_DIR}/lib/common.sh"
. "${SCRIPT_DIR}/lib/os.sh"
. "${SCRIPT_DIR}/lib/pkg.sh"
. "${SCRIPT_DIR}/lib/kokoro.sh"

# ─── Install steps ─────────────────────────────────────────────────

header() {
  cat <<-EOF
╔══════════════════════════════════════╗
║     🎤 Kokoro TTS Installer         ║
╚══════════════════════════════════════╝
EOF
}

step_system() {
  log_step "System dependencies"

  local pkg_manager
  pkg_manager="$(os_pkg_manager)"

  log_info "OS: $(os_pretty_name)"
  log_info "Package manager: ${pkg_manager}"

  local deps
  deps="$(kokoro_install_system_deps "${pkg_manager}")"

  pkg_install "${pkg_manager}" ${deps}
  log_ok "System dependencies installed"
}

step_validate() {
  log_step "Environment validation"

  require_cmd python3
  require_cmd pip3
  require_cmd curl

  if ldconfig -p 2>/dev/null | grep -q "libespeak-ng.so"; then
    log_ok "libespeak-ng.so found"
  else
    log_warn "libespeak-ng.so not in ldconfig — may fail"
  fi

  log_ok "Environment valid"
}

step_models() {
  log_step "Kokoro models"
  kokoro_download_models
}

step_python() {
  log_step "Python package"
  kokoro_install_python_pkg
}

step_env() {
  log_step "Environment config"
  kokoro_write_env
}

step_test() {
  log_step "Generation test"
  kokoro_test
}

summary() {
  local env_path
  env_path="$(kokoro_env_path)"

  cat <<-EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  🎤 Kokoro TTS — Install complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  OS:      $(os_pretty_name)
  Models:  ${KOKORO_DIR}
  Env:     ${env_path}
  Audio:   /tmp/kokoro-test.wav

  To play:
    ffplay /tmp/kokoro-test.wav
    aplay  /tmp/kokoro-test.wav
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
}

# ─── Main ───────────────────────────────────────────────────────────

main() {
  header
  echo

  require_sudo

  step_system
  step_validate
  step_models
  step_python
  step_env
  step_test
  summary
}

main "$@"
