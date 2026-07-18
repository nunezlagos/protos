# lib/os.sh — detección de sistema operativo

# Imprime: ID
#   Salida: "arch" | "ubuntu" | "debian" | "fedora" | ...
os_id() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    printf "%s" "${ID}"
  else
    printf "unknown"
  fi
}

# Imprime: nombre legible
os_pretty_name() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    printf "%s" "${PRETTY_NAME:-${ID}}"
  else
    printf "unknown"
  fi
}

# Imprime: "pacman" | "apt" | "dnf" | "zypper" | "apk" | "unknown"
os_pkg_manager() {
  local id
  id="$(os_id)"

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
      else
        printf "unknown"
      fi
      ;;
  esac
}
