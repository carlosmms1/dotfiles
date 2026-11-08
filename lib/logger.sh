#!/usr/bin/env bash
# shellcheck shell=bash
# Shared logging helpers.
#
# Requires: LOG_FILE (optional). When set, every entry is also appended to it.

if [[ -z "${NO_COLOR:-}" && -t 1 ]]; then
  readonly RED=$'\033[0;31m'
  readonly GREEN=$'\033[0;32m'
  readonly YELLOW=$'\033[1;33m'
  readonly BLUE=$'\033[0;34m'
  readonly MAGENTA=$'\033[0;35m'
  readonly CYAN=$'\033[0;36m'
  readonly NC=$'\033[0m'
else
  readonly RED=''
  readonly GREEN=''
  readonly YELLOW=''
  readonly BLUE=''
  readonly MAGENTA=''
  readonly CYAN=''
  readonly NC=''
fi

log() {
  local level=$1
  shift
  local message="$*"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  case $level in
    INFO)    printf '%s[INFO]%s %s\n' "$BLUE" "$NC" "$message" ;;
    SUCCESS) printf '%s[✓]%s %s\n' "$GREEN" "$NC" "$message" ;;
    WARNING) printf '%s[WARN]%s %s\n' "$YELLOW" "$NC" "$message" ;;
    ERROR)   printf '%s[✗]%s %s\n' "$RED" "$NC" "$message" ;;
    STEP)    printf '\n%s[→]%s %s%s%s\n' "$MAGENTA" "$NC" "$CYAN" "$message" "$NC" ;;
    *)       printf '%s\n' "$message" ;;
  esac

  if [[ -n "${LOG_FILE:-}" ]]; then
    printf '[%s] [%s] %s\n' "$timestamp" "$level" "$message" >>"$LOG_FILE"
  fi
}
