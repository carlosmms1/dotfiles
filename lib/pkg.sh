#!/usr/bin/env bash
# shellcheck shell=bash
# Package manager abstraction.
#
# Requires: DISTRO (arch|fedora|debian) and log().

pkg_install() {
  if [[ $# -eq 0 ]]; then
    return 0
  fi

  case "${DISTRO:-}" in
    arch)
      if command_exists yay; then
        yay -S --needed --noconfirm "$@"
      else
        sudo pacman -S --needed --noconfirm "$@"
      fi
      ;;
    fedora)
      sudo dnf install -y "$@"
      ;;
    debian)
      sudo apt-get update && sudo apt-get install -y "$@"
      ;;
    *)
      log ERROR "Distro não suportada para instalação: ${DISTRO:-unknown}"
      return 1
      ;;
  esac
}

pkg_update() {
  case "${DISTRO:-}" in
    arch)
      if command_exists yay; then
        yay -Syu --noconfirm
      else
        sudo pacman -Syu --noconfirm
      fi
      ;;
    fedora)
      sudo dnf upgrade -y
      ;;
    debian)
      sudo apt-get update && sudo apt-get upgrade -y
      ;;
    *)
      log ERROR "Distro não suportada para atualização: ${DISTRO:-unknown}"
      return 1
      ;;
  esac
}

pkg_installed() {
  local package=$1

  case "${DISTRO:-}" in
    arch)
      pacman -Qi "$package" &>/dev/null || yay -Qi "$package" &>/dev/null
      ;;
    fedora)
      rpm -q "$package" &>/dev/null
      ;;
    debian)
      dpkg -s "$package" &>/dev/null
      ;;
    *)
      return 1
      ;;
  esac
}
