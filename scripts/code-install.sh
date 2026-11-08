#!/usr/bin/env bash
#
# Install Visual Studio Code and the extensions listed in vscode/extensions.txt.
# Supports Arch, Fedora and Debian-based distros.

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly EXTENSIONS_FILE="$REPO_DIR/vscode/extensions.txt"

# shellcheck source=../lib/logger.sh
source "$REPO_DIR/lib/logger.sh"
# shellcheck source=../lib/utils.sh
source "$REPO_DIR/lib/utils.sh"
# shellcheck source=../lib/detect_os.sh
source "$REPO_DIR/lib/detect_os.sh"
# shellcheck source=../lib/pkg.sh
source "$REPO_DIR/lib/pkg.sh"

LOG_FILE="${LOG_FILE:-$REPO_DIR/vscode.log}"
INSTALL_EXTENSIONS=true
FORCE=false

usage() {
  cat <<'EOF'
Usage: ./scripts/code-install.sh [OPTIONS]

Options:
  --no-extensions   Do not install the extensions from vscode/extensions.txt
  --force           Reinstall even if `code` is already available
  -h, --help        Show this help
EOF
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --no-extensions)
        INSTALL_EXTENSIONS=false
        shift
        ;;
      --force)
        FORCE=true
        shift
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

install_vscode() {
  if command_exists code && [[ "$FORCE" == false ]]; then
    log SUCCESS "VS Code já está instalado: $(command -v code)"
    return 0
  fi

  log STEP "Instalando VS Code ($DISTRO)"

  case "$DISTRO" in
    arch)
      pkg_install visual-studio-code-bin || pkg_install code
      ;;
    fedora)
      sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc

      sudo tee /etc/yum.repos.d/vscode.repo >/dev/null <<'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
autorefresh=1
type=rpm-md
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

      sudo dnf install -y code
      ;;
    debian)
      sudo apt-get update
      sudo apt-get install -y wget gpg

      wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
        | sudo gpg --dearmor -o /usr/share/keyrings/microsoft.gpg

      sudo tee /etc/apt/sources.list.d/vscode.sources >/dev/null <<'EOF'
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64,arm64,armhf
Signed-By: /usr/share/keyrings/microsoft.gpg
EOF

      sudo apt-get update
      sudo apt-get install -y code
      ;;
    *)
      error_exit "Distro não suportada para instalar o VS Code: $DISTRO"
      ;;
  esac

  if command_exists code; then
    log SUCCESS "VS Code instalado: $(code --version | sed -n '1p')"
  else
    error_exit "VS Code não foi encontrado após a instalação"
  fi
}

install_extensions() {
  if [[ "$INSTALL_EXTENSIONS" == false ]]; then
    log INFO "Extensões ignoradas (--no-extensions)"
    return 0
  fi

  if [[ ! -f "$EXTENSIONS_FILE" ]]; then
    log WARNING "Lista de extensões não encontrada: $EXTENSIONS_FILE"
    return 0
  fi

  if ! command_exists code; then
    log WARNING "code não encontrado; pulando extensões"
    return 0
  fi

  log STEP "Instalando extensões do VS Code"

  local extension
  while IFS= read -r extension; do
    [[ -z "$extension" || "$extension" == \#* ]] && continue
    log INFO "→ $extension"
    if code --install-extension "$extension" --force >/dev/null 2>&1; then
      log SUCCESS "$extension"
    else
      log WARNING "Falha ao instalar $extension"
    fi
  done <"$EXTENSIONS_FILE"
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

  install_vscode
  install_extensions

  log SUCCESS "Concluído"
}

main "$@"
