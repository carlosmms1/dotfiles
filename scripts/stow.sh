#!/usr/bin/env bash
#
# Stow the dotfiles packages into $HOME.
#
# Features:
#   - per-profile package selection (core / wayland / all)
#   - automatic backup of real files that would be replaced by a symlink
#   - dry-run mode
#
# Usage:
#   ./scripts/stow.sh [--profile core|wayland|all] [--dry-run] [--adopt]
#                     [--exclude pkg1,pkg2] [--backup-dir DIR]

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly STOW_DIR="$REPO_DIR/stow"

# shellcheck source=../lib/logger.sh
source "$REPO_DIR/lib/logger.sh"
# shellcheck source=../lib/utils.sh
source "$REPO_DIR/lib/utils.sh"

LOG_FILE="${LOG_FILE:-$REPO_DIR/stow.log}"

readonly CORE_PACKAGES=(
  zsh
  powerlevel10k
  kitty
  nvim
  bash
  git
  tmux
  btop
  herdr
  gh
  vscode
  opencode
  ssh
  misc
  ghostty
  claude
)

readonly WAYLAND_PACKAGES=(
  hypr
  waybar
  noctalia
)

PROFILE="core"
DRY_RUN=false
ADOPT=false
EXCLUDED=()
BACKUP_DIR=""
PACKAGES=()

usage() {
  cat <<'EOF'
Usage: ./scripts/stow.sh [OPTIONS]

Options:
  --profile core|wayland|all   Package set to stow (default: core)
  --packages "a b c"           Explicit package list (overrides --profile)
  --exclude "a,b"              Packages to skip (can be repeated)
  --dry-run                    Show what would be linked, change nothing
  --adopt                      Use `stow --adopt` instead of backing up files
  --backup-dir DIR             Where to move conflicting files
  -h, --help                   Show this help

Core packages:
  zsh powerlevel10k kitty nvim bash git tmux btop herdr gh vscode
  opencode ssh misc ghostty claude

Wayland profile (core + these):
  hypr waybar noctalia
EOF
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --profile)
        PROFILE="${2:-}"
        shift 2
        ;;
      --packages)
        read -r -a PACKAGES <<<"${2:-}"
        shift 2
        ;;
      --exclude)
        IFS=',' read -r -a _excluded <<<"${2:-}"
        EXCLUDED+=("${_excluded[@]}")
        shift 2
        ;;
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --adopt)
        ADOPT=true
        shift
        ;;
      --backup-dir)
        BACKUP_DIR="${2:-}"
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

select_packages() {
  if [[ ${#PACKAGES[@]} -gt 0 ]]; then
    return
  fi

  case "$PROFILE" in
    core)
      PACKAGES=("${CORE_PACKAGES[@]}")
      ;;
    wayland)
      PACKAGES=("${CORE_PACKAGES[@]}" "${WAYLAND_PACKAGES[@]}")
      ;;
    all)
      PACKAGES=("${CORE_PACKAGES[@]}" "${WAYLAND_PACKAGES[@]}")
      ;;
    *)
      error_exit "Perfil inválido: $PROFILE (use core, wayland ou all)"
      ;;
  esac
}

is_excluded() {
  local package=$1
  local excluded

  for excluded in "${EXCLUDED[@]}"; do
    [[ "$package" == "$excluded" ]] && return 0
  done

  return 1
}

is_same_link() {
  local target=$1
  local source=$2

  # The target may be a symlink itself or live inside a symlinked directory
  # (e.g. an older stow created ~/.config/zsh as a directory symlink).
  [[ -e "$target" ]] || return 1
  [[ "$(readlink -f "$target")" == "$(readlink -f "$source")" ]]
}

backup_conflicts() {
  local package=$1
  local source
  local relative
  local target
  local backed_up=0

  while IFS= read -r -d '' source; do
    relative="${source#"$STOW_DIR/$package/"}"
    target="$HOME/$relative"

    if is_same_link "$target" "$source"; then
      continue
    fi

    if [[ -e "$target" || -L "$target" ]]; then
      if [[ "$DRY_RUN" == true ]]; then
        log INFO "would back up: ~/$relative"
        backed_up=$((backed_up + 1))
        continue
      fi

      mkdir -p "$BACKUP_DIR/$(dirname "$relative")"
      mv "$target" "$BACKUP_DIR/$relative"
      log INFO "backup: ~/$relative -> $BACKUP_DIR/$relative"
      backed_up=$((backed_up + 1))
    fi
  done < <(find "$STOW_DIR/$package" \( -type f -o -type l \) -print0)

  if [[ $backed_up -gt 0 && "$DRY_RUN" == false ]]; then
    log INFO "$backed_up arquivo(s) movido(s) para $BACKUP_DIR"
  fi
}

stow_package() {
  local package=$1

  if [[ ! -d "$STOW_DIR/$package" ]]; then
    log WARNING "Pacote não encontrado, ignorando: $package"
    return 0
  fi

  if is_excluded "$package"; then
    log INFO "Ignorando pacote: $package"
    return 0
  fi

  log STEP "Stowing $package"

  if [[ "$ADOPT" == true && "$package" == "opencode" ]]; then
    if [[ -f "$HOME/.config/opencode/opencode.jsonc" ]] \
      && grep -qE 'napi_[A-Za-z0-9]{10,}|sk-lf-[A-Za-z0-9-]{10,}|ghp_[A-Za-z0-9]{10,}|github_pat_[A-Za-z0-9_]{10,}' "$HOME/.config/opencode/opencode.jsonc"; then
      log ERROR "opencode.jsonc contém segredo; --adopt recusado para o pacote opencode"
      return 1
    fi
  fi

  if [[ "$ADOPT" == true ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      stow --adopt --restow --no-folding -n -v -d "$STOW_DIR" -t "$HOME" "$package" || true
    else
      log WARNING "Modo --adopt: arquivos existentes serão movidos para o repositório"
      if ! stow --adopt --restow --no-folding -v -d "$STOW_DIR" -t "$HOME" "$package"; then
        log ERROR "Falha ao stowar $package"
        return 1
      fi
    fi
    return 0
  fi

  backup_conflicts "$package"

  if [[ "$DRY_RUN" == true ]]; then
    stow --restow --no-folding -n -v -d "$STOW_DIR" -t "$HOME" "$package" || true
  else
    if ! stow --restow --no-folding -v -d "$STOW_DIR" -t "$HOME" "$package"; then
      log ERROR "Falha ao stowar $package"
      return 1
    fi
  fi
}

main() {
  parse_arguments "$@"
  require_command stow
  select_packages

  if [[ "$DRY_RUN" == false && -z "$BACKUP_DIR" ]]; then
    BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d%H%M%S)"
  fi

  log INFO "Perfil: $PROFILE"
  log INFO "Backup: ${BACKUP_DIR:-<(dry-run)>}"
  log INFO "Pacotes: ${PACKAGES[*]}"

  if [[ "$DRY_RUN" == false ]]; then
    mkdir -p "$HOME"
    # Keep ~/.ssh private when the ssh package creates it on a fresh machine.
    if [[ " ${PACKAGES[*]} " == *" ssh "* ]]; then
      mkdir -p "$HOME/.ssh"
      chmod 700 "$HOME/.ssh"
    fi
  fi

  local package
  local -a failed=()
  for package in "${PACKAGES[@]}"; do
    if ! stow_package "$package"; then
      failed+=("$package")
    fi
  done

  if [[ ${#failed[@]} -gt 0 ]]; then
    log WARNING "Pacotes com falha: ${failed[*]}"
    log WARNING "Os arquivos substituídos estão em: ${BACKUP_DIR:-<dry-run>}"
    return 1
  fi

  if [[ "$DRY_RUN" == true ]]; then
    log SUCCESS "Dry-run concluído; nada foi alterado."
  else
    log SUCCESS "Dotfiles aplicados."
    if [[ -d "$BACKUP_DIR" ]]; then
      log INFO "Backup dos arquivos substituídos: $BACKUP_DIR"
    fi
  fi
}

main "$@"
