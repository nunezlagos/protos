# lib/pkg.sh — instalación de paquetes del sistema

# Recibe: gestor (pacman|apt|dnf|zypper|apk) + paquetes...
# Delega al handler de cada gestor.
pkg_install() {
  local manager="$1"
  shift

  case "${manager}" in
    pacman) pkg_pacman "$@" ;;
    apt)    pkg_apt "$@" ;;
    dnf)    pkg_dnf "$@" ;;
    zypper) pkg_zypper "$@" ;;
    apk)    pkg_apk "$@" ;;
    *)      log_fail "gestor de paquetes '${manager}' no soportado"
  esac
}

pkg_pacman() {
  ${SUDO} pacman -S --needed --noconfirm "$@" >/dev/null 2>&1
}

pkg_apt() {
  ${SUDO} apt update -qq 2>/dev/null
  ${SUDO} apt install -y -qq "$@" >/dev/null 2>&1
}

pkg_dnf() {
  ${SUDO} dnf install -y "$@" >/dev/null 2>&1
}

pkg_zypper() {
  ${SUDO} zypper --non-interactive install "$@" >/dev/null 2>&1
}

pkg_apk() {
  ${SUDO} apk add --no-cache "$@" >/dev/null 2>&1
}
