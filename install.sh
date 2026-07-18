#!/usr/bin/env bash
# install.sh — entry point, orquesta la instalación de Kokoro TTS
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ─── Cargar módulos ────────────────────────────────────────────────
. "${SCRIPT_DIR}/lib/common.sh"
. "${SCRIPT_DIR}/lib/os.sh"
. "${SCRIPT_DIR}/lib/pkg.sh"
. "${SCRIPT_DIR}/lib/kokoro.sh"

# ─── Pasos de instalación ──────────────────────────────────────────

header() {
  cat <<-EOF
╔══════════════════════════════════════╗
║     🎤 Kokoro TTS Installer         ║
╚══════════════════════════════════════╝
EOF
}

step_system() {
  log_step "Dependencias del sistema"

  local pkg_manager
  pkg_manager="$(os_pkg_manager)"

  log_info "OS: $(os_pretty_name)"
  log_info "Gestor de paquetes: ${pkg_manager}"

  local deps
  deps="$(kokoro_install_system_deps "${pkg_manager}")"

  pkg_install "${pkg_manager}" ${deps}
  log_ok "Dependencias del sistema instaladas"
}

step_validate() {
  log_step "Validando entorno"

  require_cmd python3
  require_cmd pip3
  require_cmd curl

  if ldconfig -p 2>/dev/null | grep -q "libespeak-ng.so"; then
    log_ok "libespeak-ng.so detectada"
  else
    log_warn "libespeak-ng.so no encontrada en ldconfig — puede fallar"
  fi

  log_ok "Entorno válido"
}

step_models() {
  log_step "Modelos Kokoro"
  kokoro_download_models
}

step_python() {
  log_step "Paquete Python"
  kokoro_install_python_pkg
}

step_env() {
  log_step "Configuración"
  kokoro_write_env
}

step_test() {
  log_step "Prueba de generación"
  kokoro_test
}

summary() {
  local env_path
  env_path="$(kokoro_env_path)"

  cat <<-EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  🎤 Kokoro TTS — Instalación completa
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  OS:      $(os_pretty_name)
  Modelos: ${KOKORO_DIR}
  Env:     ${env_path}
  Audio:   /tmp/kokoro-test.wav

  Para escuchar:
    ffplay /tmp/kokoro-test.wav
    aplay  /tmp/kokoro-test.wav
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
}

# ─── Main ──────────────────────────────────────────────────────────

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
