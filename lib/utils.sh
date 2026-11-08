#!/usr/bin/env bash
# shellcheck shell=bash
# Small shared helpers.

command_exists() {
  command -v "$1" &>/dev/null
}

error_exit() {
  log ERROR "$1"
  exit 1
}

require_command() {
  if ! command_exists "$1"; then
    error_exit "Comando obrigatório não encontrado: $1"
  fi
}
