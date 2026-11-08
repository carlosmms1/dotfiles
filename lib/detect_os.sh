#!/usr/bin/env bash
# shellcheck shell=bash
# Distro detection. Outputs one of: arch, fedora, debian, unknown.

detect_distro() {
  if [[ ! -r /etc/os-release ]]; then
    echo "unknown"
    return
  fi

  (
    # shellcheck disable=SC1091
    . /etc/os-release

    case "${ID:-}" in
      arch|manjaro|endeavouros|garuda|artix|cachyos) echo "arch" ;;
      fedora|rhel|centos|rocky|almalinux|ol)         echo "fedora" ;;
      debian|ubuntu|pop|linuxmint|elementary|zorin)  echo "debian" ;;
      *)
        case "${ID_LIKE:-}" in
          *arch*)             echo "arch" ;;
          *fedora*|*rhel*)    echo "fedora" ;;
          *debian*|*ubuntu*)  echo "debian" ;;
          *)                  echo "unknown" ;;
        esac
        ;;
    esac
  )
}

distro_name() {
  if [[ -r /etc/os-release ]]; then
    (
      # shellcheck disable=SC1091
      . /etc/os-release
      printf '%s\n' "${PRETTY_NAME:-${NAME:-unknown}}"
    )
  else
    echo "unknown"
  fi
}
