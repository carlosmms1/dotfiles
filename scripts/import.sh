#!/usr/bin/env bash
#
# Import live configuration from $HOME back into the stow/ tree.
# Use this after changing a tool's config on the machine, then review `git diff`.
#
# Secrets are never copied: files with tokens/passwords are skipped, and
# opencode.jsonc is sanitized to use {env:...} before being written.

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly STOW_DIR="$REPO_DIR/stow"

# shellcheck source=../lib/logger.sh
source "$REPO_DIR/lib/logger.sh"
# shellcheck source=../lib/utils.sh
source "$REPO_DIR/lib/utils.sh"

LOG_FILE="${LOG_FILE:-$REPO_DIR/import.log}"
DRY_RUN=false
PACKAGES=()

readonly IMPORTABLE=(
  bash
  git
  tmux
  btop
  herdr
  gh
  vscode
  misc
  ghostty
  ssh
  claude
  nvim
  opencode
)

usage() {
  cat <<'EOF'
Usage: ./scripts/import.sh [OPTIONS]

Options:
  --packages "a b c"   Import only these packages
  --dry-run            Show what would be copied, change nothing
  -h, --help           Show this help

Importable packages:
  bash git tmux btop herdr gh vscode misc ghostty ssh claude nvim opencode

Not imported (secrets/runtime):
  opencode/cli.json, opencode/service.json, opencode/secrets/,
  opencode/github-mcp.env, opencode/opencode-langfuse.json
EOF
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --packages)
        read -r -a PACKAGES <<<"${2:-}"
        shift 2
        ;;
      --dry-run)
        DRY_RUN=true
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

  if [[ ${#PACKAGES[@]} -eq 0 ]]; then
    PACKAGES=("${IMPORTABLE[@]}")
  fi
}

scan_secrets() {
  local file=$1

  if grep -qE 'napi_[A-Za-z0-9]{10,}|sk-lf-[A-Za-z0-9-]{10,}|ghp_[A-Za-z0-9]{10,}|github_pat_[A-Za-z0-9_]{10,}|GITHUB_PERSONAL_ACCESS_TOKEN=[A-Za-z0-9]|token_pepper[[:space:]]*=[[:space:]]*"[a-f0-9]{20,}|"password"[[:space:]]*:[[:space:]]*"[^"]+"' "$file"; then
    log ERROR "Segredo detectado em $file; arquivo não importado"
    return 1
  fi
}

copy_file() {
  local source=$1
  local destination=$2

  if [[ ! -f "$source" ]]; then
    log WARNING "Não encontrado: $source"
    return 0
  fi

  if [[ -e "$destination" && "$(readlink -f "$source")" == "$(readlink -f "$destination")" ]]; then
    log INFO "já sincronizado: $source"
    return 0
  fi

  if ! scan_secrets "$source"; then
    return 0
  fi

  if [[ "$DRY_RUN" == true ]]; then
    log INFO "copiaria: $source -> $destination"
    return 0
  fi

  install -D -m 644 "$source" "$destination"
  log SUCCESS "importado: $destination"
}

copy_sanitized_opencode() {
  local source="$HOME/.config/opencode/opencode.jsonc"
  local destination="$STOW_DIR/opencode/.config/opencode/opencode.jsonc"
  local temporary
  temporary="$(mktemp)"

  [[ -f "$source" ]] || { log WARNING "Não encontrado: $source"; return 0; }

  sed -E 's|("Authorization"[[:space:]]*:[[:space:]]*"Bearer )[^"]+(")|\1{env:NEON_API_KEY}\2|' \
    "$source" >"$temporary"

  if ! scan_secrets "$temporary"; then
    rm -f "$temporary"
    return 0
  fi

  if [[ "$DRY_RUN" == true ]]; then
    log INFO "copiaria (sanitizado): $source -> $destination"
  else
    install -D -m 644 "$temporary" "$destination"
    log SUCCESS "importado (sanitizado): $destination"
  fi

  rm -f "$temporary"
}

import_bash() {
  local file
  for file in .bashrc .bash_profile .profile .zshenv; do
    copy_file "$HOME/$file" "$STOW_DIR/bash/$file"
  done
}

import_git() {
  copy_file "$HOME/.gitconfig" "$STOW_DIR/git/.gitconfig"
}

import_tmux() {
  copy_file "$HOME/.tmux.conf" "$STOW_DIR/tmux/.tmux.conf"
}

import_btop() {
  copy_file "$HOME/.config/btop/btop.conf" "$STOW_DIR/btop/.config/btop/btop.conf"
}

import_herdr() {
  copy_file "$HOME/.config/herdr/config.toml" "$STOW_DIR/herdr/.config/herdr/config.toml"
}

import_gh() {
  copy_file "$HOME/.config/gh/config.yml" "$STOW_DIR/gh/.config/gh/config.yml"
}

import_vscode() {
  copy_file "$HOME/.config/Code/User/settings.json" "$STOW_DIR/vscode/.config/Code/User/settings.json"

  if command_exists code; then
    if [[ "$DRY_RUN" == true ]]; then
      log INFO "atualizaria vscode/extensions.txt"
    else
      code --list-extensions | sort >"$REPO_DIR/vscode/extensions.txt"
      log SUCCESS "atualizado: vscode/extensions.txt"
    fi
  fi
}

import_misc() {
  copy_file "$HOME/.npmrc" "$STOW_DIR/misc/.npmrc"
  copy_file "$HOME/.tool-versions" "$STOW_DIR/misc/.tool-versions"
}

import_ghostty() {
  if [[ -f "$HOME/.config/ghostty/config" ]]; then
    copy_file "$HOME/.config/ghostty/config" "$STOW_DIR/ghostty/.config/ghostty/config"
  elif [[ -f "$HOME/.config/ghostty/config.ghostty" ]]; then
    copy_file "$HOME/.config/ghostty/config.ghostty" "$STOW_DIR/ghostty/.config/ghostty/config"
  fi
}

import_ssh() {
  copy_file "$HOME/.ssh/config" "$STOW_DIR/ssh/.ssh/config"
}

import_claude() {
  local source="$HOME/.claude/settings.json"
  local destination="$STOW_DIR/claude/.claude/settings.json"
  local temporary
  temporary="$(mktemp)"

  [[ -f "$source" ]] || { log WARNING "Não encontrado: $source"; return 0; }

  sed -E 's|/home/[^/"]+|$HOME|g' "$source" >"$temporary"

  if [[ "$DRY_RUN" == true ]]; then
    log INFO "copiaria (path sanitizado): $source -> $destination"
  else
    install -D -m 644 "$temporary" "$destination"
    log SUCCESS "importado (path sanitizado): $destination"
  fi

  rm -f "$temporary"
}

import_nvim() {
  local source="$HOME/.config/nvim"
  local destination="$STOW_DIR/nvim/.config/nvim"

  if [[ ! -d "$source" ]]; then
    log WARNING "Não encontrado: $source"
    return 0
  fi

  if [[ -e "$source/init.lua" && -e "$destination/init.lua" ]] \
    && [[ "$(readlink -f "$source/init.lua")" == "$(readlink -f "$destination/init.lua")" ]]; then
    log INFO "nvim já está linkado ao repo; nada a importar"
    return 0
  fi

  if [[ "$DRY_RUN" == true ]]; then
    log INFO "copiaria (rsync): $source/ -> $destination/"
    return 0
  fi

  if command_exists rsync; then
    rsync -aL --delete "$source/" "$destination/"
  else
    rm -rf "$destination"
    mkdir -p "$destination"
    cp -aL "$source/." "$destination/"
  fi

  log SUCCESS "importado: $destination"
}

import_opencode() {
  local source="$HOME/.config/opencode"
  local destination="$STOW_DIR/opencode/.config/opencode"
  local file

  copy_sanitized_opencode

  for file in tui.jsonc herdr-tui-session.js package.json; do
    copy_file "$source/$file" "$destination/$file"
  done

  copy_file "$source/herdr-opencode/tui.js" "$destination/herdr-opencode/tui.js"
  copy_file "$source/plugins/herdr-agent-state.js" "$destination/plugins/herdr-agent-state.js"
  copy_file "$source/plugins/ai-memory-opencode2.ts" "$destination/plugins/ai-memory-opencode2.ts"
  copy_file "$source/skills/adr-records/SKILL.md" "$destination/skills/adr-records/SKILL.md"

  log INFO "Ignorando arquivos com segredo/runtime do opencode (cli.json, service.json, secrets/, github-mcp.env, opencode-langfuse.json)"
}

import_package() {
  local package=$1

  case "$package" in
    bash)     import_bash ;;
    git)      import_git ;;
    tmux)     import_tmux ;;
    btop)     import_btop ;;
    herdr)    import_herdr ;;
    gh)       import_gh ;;
    vscode)   import_vscode ;;
    misc)     import_misc ;;
    ghostty)  import_ghostty ;;
    ssh)      import_ssh ;;
    claude)   import_claude ;;
    nvim)     import_nvim ;;
    opencode) import_opencode ;;
    *)
      log WARNING "Pacote não importável: $package"
      return 0
      ;;
  esac
}

main() {
  parse_arguments "$@"

  log INFO "Pacotes: ${PACKAGES[*]}"
  log INFO "Dry-run: $DRY_RUN"

  local package
  for package in "${PACKAGES[@]}"; do
    log STEP "Importando $package"
    import_package "$package"
  done

  if [[ "$DRY_RUN" == true ]]; then
    log SUCCESS "Dry-run concluído; nada foi alterado."
  else
    log SUCCESS "Importação concluída. Revise com: git diff"
  fi
}

main "$@"
