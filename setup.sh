#!/bin/bash

set -e

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DOTFILES_DIR="$SCRIPT_DIR"
readonly BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d%H%M)"
readonly LOG_FILE="$SCRIPT_DIR/bootstrap.log"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

UPDATE_SYSTEM=true
SETUP_PACKAGES=true
SETUP_DOTFILES=true
SETUP_FONTS=true
SETUP_ZSH=true
SETUP_THEMES=true

log() {
    local level=$1; shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case $level in
        INFO)    echo -e "${BLUE}[INFO]${NC} $message" ;;
        SUCCESS) echo -e "${GREEN}[✓]${NC} $message" ;;
        WARNING) echo -e "${YELLOW}[WARN]${NC} $message" ;;
        ERROR)   echo -e "${RED}[✗]${NC} $message" ;;
        STEP)    echo -e "\n${MAGENTA}[→]${NC} ${CYAN}$message${NC}" ;;
    esac

    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

command_exists() {
    command -v "$1" &>/dev/null
}

error_exit() {
    log ERROR "$1"
    exit 1
}

package_installed() {
    pacman -Qi "$1" &>/dev/null || yay -Qi "$1" &>/dev/null 2>&1
}

# ===============================
# SETUP YAY (YET ANOTHER YOUGURT)
# ===============================

setup_yay() {
	if ! command_exists yay; then
		log INFO "Installing yay"

		sudo pacman -S --needed git base-devel
		git clone https://aur.archlinux.org/yay.git /tmp/yay
		cd /tmp/yay
		makepkg -si --noconfirm
		cd "$HOME"

		log SUCCESS "Yay installed"
	fi

	log INFO "Yay already installed"
}

# =============
# UPDATE SYSTEM
# =============

update_system() {
	log INFO "Updating system..."

	# Ensure sudo
	sudo -v

	log INFO "Refreshing mirrors..."
	sudo pacman -Sy --noconfirm reflector || true

	log INFO "Updating keyrings..."
	sudo pacman -Sy --noconfirm archlinux-keyring

	log INFO "Upgrading system..."
	yay -Syu --noconfirm --sudoloop --timeupdate

	log SUCCESS "System updated!"
}

# ==============
# SETUP PACKAGES
# ==============

setup_packages() {
	log STEP "Installing packages..."

	local packages_file="$SCRIPT_DIR/packages.txt"

	if [ ! -f "$packages_file" ]; then
		error_exit "Packages list not found: $packages_file"
	fi

	log INFO "Installing packages from list..."

	if yay -S --needed --noconfirm \
        	$(grep -vE '^\s*#|^\s*$' "$packages_file"); then
        	log SUCCESS "All packages installed successfully"
    	else
        	error_exit "Package installation failed"
    	fi
}

# ========================
# NERD FONTS CONFIGURATION
# ========================

# setup_fonts() {
#     log STEP "Installing Nerd Fonts..."
#
#     # Verifica se a fonte já está instalada
#     if fc-list | grep -qi "JetBrainsMonoNerdFont"; then
#         log INFO "JetBrains Mono Nerd Font already installed"
#     else
#         log INFO "Installing ttf-jetbrains-mono-nerd..."
#         sudo pacman -S --noconfirm --needed ttf-jetbrains-mono-nerd
#         log SUCCESS "JetBrains Mono Nerd Font installed"
#     fi
#
#     # Atualiza o cache de fontes do sistema
#     log INFO "Updating fonts cache..."
#     fc-cache -fv &>/dev/null
#     log SUCCESS "Fonts cache updated"
# }

# ===================
# SHELL CONFIGURATION
# ===================

setup_zsh() {
    log STEP "Configuring ZSH environment..."

    # Install ZSH if not present
    if ! command_exists zsh; then
        log INFO "Installing ZSH..."
        yay -S --noconfirm --needed zsh git
    fi

    # Install Oh My Zsh
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        log INFO "Installing Oh My Zsh..."
        RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    else
        log INFO "Oh My Zsh already installed"
    fi

    # Install ZSH plugins
    local plugins="$HOME/.oh-my-zsh/custom/plugins"

    # zsh-autosuggestions
    if [ ! -d "$plugins/zsh-autosuggestions" ]; then
        log INFO "Installing zsh-autosuggestions..."
        git clone https://github.com/zsh-users/zsh-autosuggestions "$plugins/zsh-autosuggestions"
    fi

    # zsh-syntax-highlighting
    if [ ! -d "$plugins/zsh-syntax-highlighting" ]; then
        log INFO "Installing zsh-syntax-highlighting..."
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$plugins/zsh-syntax-highlighting"
    fi

    # Set ZSH as default shell
    if [ "$SHELL" != "$(which zsh)" ]; then
        log INFO "Setting ZSH as default shell..."
        chsh -s "$(which zsh)"
        log SUCCESS "Default shell changed to ZSH (restart your terminal)"
    fi

    log SUCCESS "ZSH environment configured"
}

# ============
# SETUP THEMES
# ============

setup_themes() {
        log STEP "Configuring OMZ themes..."

	local omz_themes="$HOME/.oh-my-zsh/custom/themes"

	if [ ! -d "$omz_themes/powerlevel10k" ]; then
		log INFO "Installing powerlevel10k theme..."
		git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$omz_themes/powerlevel10k"
	fi

	log SUCCESS "OMZ Themes configured!"
}

# ==============
# SETUP DOTFILES
# ==============

setup_dotfiles() {
	log INFO "Setting up dotfiles with GNU Stow"

	if ! command_exists stow; then
		log INFO "Installing GNU Stow..."
		yay -S --noconfirm --needed stow
	fi

	log INFO "Stowing dotfiles..."
	cd "$SCRIPT_DIR/stow"
	
	for dir in */; do
		echo -e "${CYAN}[]${NC} Stowing ${CYAN}${dir%/}${NC}"
		stow -t "$HOME" --restow "${dir%/}"
	done

	log SUCCESS "All dotfiles stowed!"
}

# ==============
# VALIDATE SETUP
# ==============

validate() {
    log STEP "Validating bootstrap..."

    local errors=0

    check_cmd() {
        if command_exists "$1"; then
            log INFO "✓ $1"
        else
            log ERROR "✗ $1 não encontrado"
            ((errors++))
        fi
    }

    check_cmd zsh
    check_cmd git
    check_cmd curl

    [[ -d "$HOME/.oh-my-zsh" ]] \
        && log INFO "✓ Oh My Zsh" \
        || { log ERROR "✗ Oh My Zsh not found"; ((errors++)); }

    fc-list | grep -qi "JetBrainsMonoNerdFont" \
        && log INFO "✓ JetBrains Mono Nerd Font" \
        || { log ERROR "✗ JetBrains Mono Nerd Font not found"; ((errors++)); }

    fc-list | grep -qi "MesloLGSNerdFontMono" \
        && log INFO "✓ MesloLGS Nerd Font Mono" \
        || { log ERROR "✗ MesloLGS Nerd Font Mono not found"; ((errors++)); }

    if [[ $errors -eq 0 ]]; then
        log SUCCESS "All passes!"
    else
        log WARNING "$errors item(s) with problems. Verify the log: $LOG_FILE"
    fi
}

check_system() {
    log STEP "Verifying system..."
 
    [[ -f /etc/arch-release ]] || error_exit "This script is only for Arch Linux."
    sudo -v                    || error_exit "Sudo privilegies required!"
    ping -c 1 archlinux.org &>/dev/null || error_exit "No internet connection..."
 
    log SUCCESS "System OK"
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-zsh)            SETUP_ZSH=false ;;
            --no-update-system)  UPDATE_SYSTEM=false ;;
            --no-dotfiles)       SETUP_DOTFILES=false ;;
            --no-themes)         SETUP_THEMES=false ;;
            --help|-h)
                echo "Use: $0 [OPTIONS]"
                echo
                echo "Options:"
                echo "  --no-zsh              Skip zsh installation/configuration"
                echo "  --no-update-system    Skip system update"
                echo "  --no-packages         Skip system packages installation"
                echo "  --no-dotfiles         Skip dotfiles setup"
                echo "  --no-themes    	      Skip OMZ themes configuration"
                echo "  --help, -h            Shows help"
                exit 0
                ;;
            *)
                log ERROR "Unknown option: $1"
                exit 1
                ;;
        esac
        shift
    done
}

main() {
    echo "Installation started at $(date)" > "$LOG_FILE"

    echo -e "${CYAN}"
    echo "  ╔══════════════════════════════════════╗"
    echo "  ║           Environment Setup          ║"
    echo "  ║     Arch Linux · ZSH · Nerd Fonts    ║"
    echo "  ╚══════════════════════════════════════╝"
    echo -e "${NC}"

    parse_arguments "$@"
    check_system

    echo
    log INFO "Steps to be executed:"
    echo "  • Yay (Yet Another Yogurt)"
    $UPDATE_SYSTEM   && echo "  • Update system"
    $SETUP_PACKAGES  && echo "  • System packages"
    $SETUP_ZSH       && echo "  • ZSH"
    $SETUP_THEMES    && echo "  • Setup OMZ themes"
    $SETUP_DOTFILES  && echo "  • Setup dotfiles"
    echo

    read -rp "$(echo -e "${CYAN}Continue? [y/N]:${NC} ")" confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { log INFO "Canceled."; exit 0; }

    setup_yay
    $UPDATE_SYSTEM   && update_system
    $SETUP_PACKAGES  && setup_packages
    $SETUP_ZSH       && setup_zsh
    $SETUP_THEMES    && setup_themes
    $SETUP_DOTFILES  && setup_dotfiles

    validate

    echo -e "${GREEN}"
    echo "╔════════════════════════════════════════╗"
    echo "║Instalação concluída!                   ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    log INFO "Próximos passos:"
    echo "  1. Reinicie o terminal (ou faça logout/login)"
    echo "  2. Adicione os plugins no seu .zshrc se ainda não estiverem"
    echo "  3. Adicione novas etapas ao script conforme precisar"
    echo
    log INFO "Log completo: $LOG_FILE"
}

main "$@"
