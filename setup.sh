#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DOTFILES_DIR="$SCRIPT_DIR"
readonly LOG_FILE="$SCRIPT_DIR/bootstrap.log"

# shellcheck source=lib/logger.sh
source "$SCRIPT_DIR/lib/logger.sh"
# shellcheck source=lib/utils.sh
source "$SCRIPT_DIR/lib/utils.sh"
# shellcheck source=lib/detect_os.sh
source "$SCRIPT_DIR/lib/detect_os.sh"
# shellcheck source=lib/pkg.sh
source "$SCRIPT_DIR/lib/pkg.sh"

DISTRO="$(detect_distro)"

PROFILE="core"
UPDATE_SYSTEM=true
SETUP_PACKAGES=true
SETUP_ZSH=true
SETUP_THEMES=true
SETUP_DOTFILES=true
SETUP_FONTS=true
SETUP_VSCODE=true
SETUP_TMUX_PLUGINS=true
ASSUME_YES=false

# ===============================
# SYSTEM CHECKS
# ===============================

check_system() {
  log STEP "Verificando sistema..."

  case "$DISTRO" in
    arch|fedora|debian)
      ;;
    *)
      error_exit "Distro não suportada: $(distro_name). Suportadas: Arch, Fedora, Debian/Ubuntu."
      ;;
  esac

  log INFO "Distro: $(distro_name) ($DISTRO)"

  sudo -v || error_exit "Privilégios de sudo são necessários"

  if command_exists ping; then
    if ! ping -c 1 -W 2 github.com &>/dev/null; then
      if ! command_exists curl || ! curl -fsI https://github.com &>/dev/null; then
        error_exit "Sem conexão com a internet"
      fi
    fi
  elif command_exists curl; then
    if ! curl -fsI https://github.com &>/dev/null; then
      error_exit "Sem conexão com a internet"
    fi
  else
    log WARNING "Não foi possível testar a conexão (ping/curl ausentes)"
  fi

  log SUCCESS "Sistema OK"
}

# ===============================
# PACKAGE MANAGER BOOTSTRAP
# ===============================

setup_pkg_manager() {
  if [[ "$DISTRO" != "arch" ]]; then
    log INFO "Gerenciador de pacotes: $DISTRO (nada a preparar)"
    return 0
  fi

  if command_exists yay; then
    log INFO "yay já instalado"
    return 0
  fi

  log INFO "Instalando yay (AUR helper)..."
  sudo pacman -S --needed --noconfirm git base-devel

  local tmp_dir
  tmp_dir="$(mktemp -d)"

  git clone --depth=1 https://aur.archlinux.org/yay.git "$tmp_dir/yay"
  (
    cd "$tmp_dir/yay"
    makepkg -si --noconfirm
  )
  rm -rf "$tmp_dir"

  log SUCCESS "yay instalado"
}

# =============
# UPDATE SYSTEM
# =============

update_system() {
  log STEP "Atualizando sistema..."
  sudo -v
  pkg_update
  log SUCCESS "Sistema atualizado"
}

# ==============
# SETUP PACKAGES
# ==============

setup_packages() {
  log STEP "Instalando pacotes..."

  local -a package_files=()
  local core_file="$SCRIPT_DIR/packages/$DISTRO.txt"
  local wayland_file="$SCRIPT_DIR/packages/$DISTRO-wayland.txt"

  if [[ ! -f "$core_file" && "$DISTRO" == "arch" ]]; then
    core_file="$SCRIPT_DIR/packages.txt"
  fi

  if [[ "$PROFILE" == "core" || "$PROFILE" == "wayland" || "$PROFILE" == "all" ]]; then
    if [[ -f "$core_file" ]]; then
      package_files+=("$core_file")
    fi
  fi

  if [[ "$PROFILE" == "wayland" || "$PROFILE" == "all" ]]; then
    if [[ -f "$wayland_file" ]]; then
      package_files+=("$wayland_file")
    fi
  fi

  if [[ ${#package_files[@]} -eq 0 ]]; then
    log WARNING "Nenhuma lista de pacotes encontrada para $DISTRO/$PROFILE"
    return 0
  fi

  local packages_file
  for packages_file in "${package_files[@]}"; do
    log INFO "Lista: $packages_file"
  done

  local -a packages=()
  local line
  for packages_file in "${package_files[@]}"; do
    while IFS= read -r line || [[ -n "$line" ]]; do
      line="${line%%#*}"
      line="${line#"${line%%[![:space:]]*}"}"
      line="${line%"${line##*[![:space:]]}"}"
      if [[ -z "$line" ]]; then
        continue
      fi
      packages+=("$line")
    done <"$packages_file"
  done

  if [[ ${#packages[@]} -eq 0 ]]; then
    log WARNING "Nenhum pacote na lista"
    return 0
  fi

  if pkg_install "${packages[@]}"; then
    log SUCCESS "Todos os pacotes instalados"
    return 0
  fi

  log WARNING "Instalação em lote falhou; tentando pacote por pacote..."
  local -a failed=()
  local package
  for package in "${packages[@]}"; do
    if pkg_install "$package"; then
      log SUCCESS "$package"
    else
      log WARNING "Falhou: $package"
      failed+=("$package")
    fi
  done

  if [[ ${#failed[@]} -gt 0 ]]; then
    log WARNING "${#failed[@]} pacote(s) falharam: ${failed[*]}"
    log WARNING "Veja os repositórios opcionais em packages/$DISTRO.txt"
  fi
}

# =======================
# NERD FONTS
# =======================

setup_fonts() {
  log STEP "Instalando Nerd Fonts..."
  "$SCRIPT_DIR/scripts/nf-install.sh"
  log SUCCESS "Fontes configuradas"
}

# ===================
# SHELL CONFIGURATION
# ===================

setup_zsh() {
  log STEP "Configurando ZSH..."

  if ! command_exists zsh; then
    log INFO "Instalando ZSH..."
    pkg_install zsh || error_exit "Falha ao instalar ZSH"
  fi

  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    log INFO "Instalando Oh My Zsh..."
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  else
    log INFO "Oh My Zsh já instalado"
  fi

  local plugins="$HOME/.oh-my-zsh/custom/plugins"
  local plugin
  for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
    if [[ ! -d "$plugins/$plugin" ]]; then
      log INFO "Instalando $plugin..."
      git clone "https://github.com/zsh-users/$plugin.git" "$plugins/$plugin"
    fi
  done

  if [[ "${SHELL:-}" != "$(command -v zsh)" ]]; then
    log INFO "Definindo ZSH como shell padrão..."
    if chsh -s "$(command -v zsh)"; then
      log SUCCESS "Shell padrão alterado (reinicie a sessão)"
    else
      log WARNING "Não foi possível alterar o shell; rode: chsh -s $(command -v zsh)"
    fi
  fi

  log SUCCESS "ZSH configurado"
}

# ============
# SETUP THEMES
# ============

setup_themes() {
  log STEP "Configurando tema do Oh My Zsh..."

  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    log WARNING "Oh My Zsh não está instalado; pulando tema"
    return 0
  fi

  local omz_themes="$HOME/.oh-my-zsh/custom/themes"

  if [[ ! -d "$omz_themes/powerlevel10k" ]]; then
    log INFO "Instalando powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$omz_themes/powerlevel10k"
  else
    log INFO "powerlevel10k já instalado"
  fi

  log SUCCESS "Tema configurado"
}

# ==============
# SETUP DOTFILES
# ==============

setup_dotfiles() {
  log STEP "Aplicando dotfiles com GNU Stow..."
  "$SCRIPT_DIR/scripts/stow.sh" --profile "$PROFILE"
  log SUCCESS "Dotfiles aplicados"
}

# =================
# VS CODE
# =================

setup_vscode() {
  log STEP "Instalando VS Code e extensões..."
  "$SCRIPT_DIR/scripts/code-install.sh"
  log SUCCESS "VS Code configurado"
}

# =================
# TMUX PLUGINS
# =================

setup_tmux_plugins() {
  if ! command_exists tmux; then
    log WARNING "tmux não encontrado; pulando plugins"
    return 0
  fi

  log STEP "Instalando plugins do tmux..."

  if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
    log INFO "Clonando TPM..."
    git clone --depth=1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
  fi

  if [[ -x "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]]; then
    tmux start-server &>/dev/null || true
    if "$HOME/.tmux/plugins/tpm/bin/install_plugins" &>/dev/null; then
      log SUCCESS "Plugins do tmux instalados"
    else
      log WARNING "Abra o tmux e pressione prefix + I para instalar os plugins"
    fi
  fi
}

# ==============
# VALIDATE SETUP
# ==============

validate() {
  log STEP "Validando instalação..."

  local errors=0

  check_cmd() {
    if command_exists "$1"; then
      log INFO "✓ $1"
    else
      log ERROR "✗ $1 não encontrado"
      errors=$((errors + 1))
    fi
  }

  check_link() {
    if [[ -L "$1" ]]; then
      log INFO "✓ ~/${1#"$HOME/"}"
    else
      log ERROR "✗ ~/${1#"$HOME/"} não é um symlink (stow não aplicado?)"
      errors=$((errors + 1))
    fi
  }

  if [[ "$SETUP_ZSH" == true ]]; then
    check_cmd zsh
    [[ -d "$HOME/.oh-my-zsh" ]] \
      && log INFO "✓ Oh My Zsh" \
      || { log ERROR "✗ Oh My Zsh não encontrado"; errors=$((errors + 1)); }
  fi

  check_cmd git
  check_cmd stow
  check_cmd tmux
  check_cmd nvim

  if [[ "$SETUP_DOTFILES" == true ]]; then
    check_link "$HOME/.zshrc"
    check_link "$HOME/.p10k.zsh"
    check_link "$HOME/.config/zsh/history.zsh"
    check_link "$HOME/.config/kitty/kitty.conf"
    check_link "$HOME/.config/nvim/init.lua"
    check_link "$HOME/.tmux.conf"
    check_link "$HOME/.gitconfig"
  fi

  if [[ "$SETUP_FONTS" == true ]] && command_exists fc-list; then
    fc-list | grep -iE 'Meslo.*Nerd' >/dev/null \
      && log INFO "✓ Meslo Nerd Font" \
      || { log ERROR "✗ Meslo Nerd Font não encontrada"; errors=$((errors + 1)); }

    fc-list | grep -iE 'JetBrainsMono.*Nerd' >/dev/null \
      && log INFO "✓ JetBrains Mono Nerd Font" \
      || { log ERROR "✗ JetBrains Mono Nerd Font não encontrada"; errors=$((errors + 1)); }
  fi

  if [[ $errors -eq 0 ]]; then
    log SUCCESS "Tudo validado"
  else
    log WARNING "$errors item(ns) com problema. Veja o log: $LOG_FILE"
  fi
}

# ==============
# ARGUMENTS
# ==============

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --profile)
        PROFILE="${2:-}"
        shift 2
        ;;
      --no-zsh)             SETUP_ZSH=false ;;
      --no-update-system)   UPDATE_SYSTEM=false ;;
      --no-packages)        SETUP_PACKAGES=false ;;
      --no-dotfiles)        SETUP_DOTFILES=false ;;
      --no-themes)          SETUP_THEMES=false ;;
      --no-fonts)           SETUP_FONTS=false ;;
      --no-vscode)          SETUP_VSCODE=false ;;
      --no-tmux-plugins)    SETUP_TMUX_PLUGINS=false ;;
      --yes|-y)             ASSUME_YES=true ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        log ERROR "Opção desconhecida: $1"
        exit 1
        ;;
    esac
    shift
  done

  case "$PROFILE" in
    core|wayland|all) ;;
    *) error_exit "Perfil inválido: $PROFILE (use core, wayland ou all)" ;;
  esac
}

usage() {
  cat <<'EOF'
Use: ./setup.sh [OPTIONS]

Perfis:
  --profile core       Dotfiles comuns (default)
  --profile wayland    Só Hyprland, Waybar e Noctalia
  --profile all        Core + Wayland

Etapas:
  --no-zsh             Pula instalação/configuração do ZSH
  --no-update-system   Pula atualização do sistema
  --no-packages        Pula instalação dos pacotes
  --no-dotfiles        Pula aplicação dos dotfiles (stow)
  --no-themes          Pula tema do Oh My Zsh
  --no-fonts           Pula instalação das Nerd Fonts
  --no-vscode          Pula VS Code e extensões
  --no-tmux-plugins    Pula plugins do tmux

Outros:
  --yes, -y            Não pede confirmação
  --help, -h           Mostra esta ajuda
EOF
}

# ==============
# MAIN
# ==============

main() {
  echo "Installation started at $(date)" >"$LOG_FILE"

  echo -e "${CYAN}"
  echo "  ╔══════════════════════════════════════╗"
  echo "  ║           Environment Setup          ║"
  echo "  ║   Arch · Fedora · Debian · ZSH       ║"
  echo "  ╚══════════════════════════════════════╝"
  echo -e "${NC}"

  parse_arguments "$@"
  check_system

  echo
  log INFO "Distro: $(distro_name) ($DISTRO)"
  log INFO "Perfil: $PROFILE"
  echo
  log INFO "Etapas que serão executadas:"
  echo "  • Gerenciador de pacotes ($DISTRO)"
  if [[ "$UPDATE_SYSTEM" == true ]]; then echo "  • Atualização do sistema"; fi
  if [[ "$SETUP_PACKAGES" == true ]]; then echo "  • Pacotes do sistema"; fi
  if [[ "$SETUP_ZSH" == true ]]; then echo "  • ZSH + Oh My Zsh + plugins"; fi
  if [[ "$SETUP_THEMES" == true ]]; then echo "  • Tema powerlevel10k"; fi
  if [[ "$SETUP_FONTS" == true ]]; then echo "  • Nerd Fonts"; fi
  if [[ "$SETUP_VSCODE" == true ]]; then echo "  • VS Code + extensões"; fi
  if [[ "$SETUP_DOTFILES" == true ]]; then echo "  • Dotfiles (stow)"; fi
  if [[ "$SETUP_TMUX_PLUGINS" == true ]]; then echo "  • Plugins do tmux"; fi
  echo

  if [[ "$ASSUME_YES" == false ]]; then
    read -rp "$(echo -e "${CYAN}Continuar? [y/N]:${NC} ")" confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { log INFO "Cancelado."; exit 0; }
  fi

  setup_pkg_manager
  if [[ "$UPDATE_SYSTEM" == true ]]; then update_system; fi
  if [[ "$SETUP_PACKAGES" == true ]]; then setup_packages; fi
  if [[ "$SETUP_ZSH" == true ]]; then setup_zsh; fi
  if [[ "$SETUP_THEMES" == true ]]; then setup_themes; fi
  if [[ "$SETUP_FONTS" == true ]]; then setup_fonts; fi
  if [[ "$SETUP_VSCODE" == true ]]; then setup_vscode; fi
  if [[ "$SETUP_DOTFILES" == true ]]; then setup_dotfiles; fi
  if [[ "$SETUP_TMUX_PLUGINS" == true ]]; then setup_tmux_plugins; fi

  validate

  echo -e "${GREEN}"
  echo "╔════════════════════════════════════════╗"
  echo "║ Instalação concluída!                  ║"
  echo "╚════════════════════════════════════════╝"
  echo -e "${NC}"
  log INFO "Próximos passos:"
  echo "  1. Crie ~/.config/opencode/.env a partir de .env.example"
  echo "  2. Reinicie o terminal (ou faça logout/login)"
  echo "  3. Abra o tmux e pressione prefix + I se os plugins não carregarem"
  echo "  4. Rode 'gh auth login' se for usar o GitHub CLI"
  echo
  log INFO "Log completo: $LOG_FILE"
}

main "$@"
