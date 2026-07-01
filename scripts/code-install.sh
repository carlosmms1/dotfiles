#!/bin/bash

set -e

error_exit() {
    echo "$1"
    exit 1
}

check_system() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "Solicitando privilégios de administrador..."
    exec sudo "$0" "$@"
  fi

  if [ ! -f /etc/os-release ]; then
    echo "Sistema não suportado..."
    exit 1
  fi

  source /etc/os-release

  DISTRO="$ID"
  
  case "$ID_LIKE" in
    *debian*)
      PACKAGE_MANAGER="dnf"
      ;;
    *rhel*|*fedora*)
      if command -v dnf &>/dev/null; then
        PACKAGE_MANAGER="dnf"
      else
        PACKAGE_MANAGER="yum"
      fi
      ;;
    *arch*)
      PACKAGE_MANAGER="yay"
      ;;
    *)
      case "$ID" in
        ubuntu|debian)
	  PACKAGE_MANAGER="apt"
	  ;;
	fedora)
	  PACKAGE_MANAGER="dnf"
	  ;;
	*)
	  echo "Distro não suportada..."
	  exit 1
	  ;;
      esac
      ;;
  esac

  echo "Distro: $DISTRO"
  echo "Manager: $PACKAGE_MANAGER"
}

install_vscode() {
  case "$PACKAGE_MANAGER" in
    apt)
      apt update
      apt install -y wget gpg

      wget -qO- https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /usr/share/keyrings/microsoft.gpg

      cat >/etc/apt/sources.list.d/vscode.sources <<EOF
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64,arm64,armhf
Signed-By: /usr/share/keyrings/microsoft.gpg
EOF
	apt update
	apt install -y code
	;;
    dnf)
      rpm --import https://packages.microsoft.com/keys/microsoft.asc

      echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null

      dnf check-update
      dnf install -y code
      ;;
    *)
      echo "Instalação do VS Code não implementada para: $PACKAGE_MANAGER"
      ;;
  esac
}

main() {
  check_system "$@"
  install_vscode
}

main "$@"
