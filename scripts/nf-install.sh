#!/usr/bin/env bash
#
# Install Nerd Fonts used by the terminal/prompt (Meslo + JetBrains Mono).
# Works on Arch, Fedora and Debian-based distros.

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../lib/logger.sh
source "$REPO_DIR/lib/logger.sh"
# shellcheck source=../lib/utils.sh
source "$REPO_DIR/lib/utils.sh"
# shellcheck source=../lib/detect_os.sh
source "$REPO_DIR/lib/detect_os.sh"
# shellcheck source=../lib/pkg.sh
source "$REPO_DIR/lib/pkg.sh"

LOG_FILE="${LOG_FILE:-$REPO_DIR/fonts.log}"
FONTS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"
NERD_FONTS_VERSION="${NERD_FONTS_VERSION:-v3.4.0}"
VERSION="$NERD_FONTS_VERSION"

usage() {
  cat <<'EOF'
Usage: ./scripts/nf-install.sh [OPTIONS]

Options:
  --version VERSION   Nerd Fonts release tag (default: v3.4.0)
  -h, --help          Show this help

Environment:
  NERD_FONTS_VERSION  Same as --version
  XDG_DATA_HOME       Font destination base (default: ~/.local/share)
EOF
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --version)
        VERSION="${2:-}"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        error_exit "Opção desconhecida: $1"
        ;;
    esac
  done
}

download() {
  local url=$1
  local destination=$2

  if command_exists curl; then
    curl -fL --retry 3 --connect-timeout 15 -o "$destination" "$url"
  elif command_exists wget; then
    wget -q -O "$destination" "$url"
  else
    error_exit "É necessário curl ou wget para baixar as fontes"
  fi
}

install_font() {
  local name=$1
  local archive="$TMP_DIR/$name.zip"
  local destination="$FONTS_DIR/$name"

  log INFO "Baixando $name ($VERSION)..."
  download "https://github.com/ryanoasis/nerd-fonts/releases/download/$VERSION/$name.zip" "$archive"

  mkdir -p "$destination"
  unzip -oq "$archive" -d "$destination"
  log SUCCESS "$name instalada em $destination"
}

validate_fonts() {
  local missing=0

  if fc-list 2>/dev/null | grep -iE 'Meslo.*Nerd' >/dev/null; then
    log INFO "✓ Meslo Nerd Font"
  else
    log ERROR "✗ Meslo Nerd Font não encontrada"
    missing=$((missing + 1))
  fi

  if fc-list 2>/dev/null | grep -iE 'JetBrainsMono.*Nerd' >/dev/null; then
    log INFO "✓ JetBrains Mono Nerd Font"
  else
    log ERROR "✗ JetBrains Mono Nerd Font não encontrada"
    missing=$((missing + 1))
  fi

  return "$missing"
}

main() {
  parse_arguments "$@"

  DISTRO="$(detect_distro)"
  log INFO "Distro: $(distro_name) ($DISTRO)"

  case "$DISTRO" in
    arch|fedora|debian)
      ;;
    *)
      error_exit "Distro não suportada: $DISTRO"
      ;;
  esac

  if ! command_exists fc-cache; then
    log INFO "Instalando fontconfig..."
    pkg_install fontconfig
  fi

  if ! command_exists unzip; then
    log INFO "Instalando unzip..."
    pkg_install unzip
  fi

  if ! command_exists curl && ! command_exists wget; then
    log INFO "Instalando curl..."
    pkg_install curl
  fi

  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM

  mkdir -p "$FONTS_DIR"

  install_font "Meslo"
  install_font "JetBrainsMono"

  log INFO "Atualizando cache de fontes..."
  fc-cache -f "$FONTS_DIR" >/dev/null

  if validate_fonts; then
    log SUCCESS "Fontes instaladas e validadas"
  else
    log WARNING "Algumas fontes não foram encontradas pelo fc-list; verifique $FONTS_DIR"
  fi
}

main "$@"
