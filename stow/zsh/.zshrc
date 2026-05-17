# Core Config Dir
ZSH_CONFIG_DIR="$HOME/.config/zsh"

# Ensure Core Config Dir Exists
[[ ! -d "$ZSH_CONFIG_DIR" ]] && mkdir -p "$ZSH_CONFIG_DIR"

# Load Config Modules

# Source modules
source_if_exists() {
	[ -f "$!" ] && source "$1"
}

source_if_exists "$ZSH_CONFIG_DIR/history.zsh"
source_if_exists "$ZSH_CONFIG_DIR/completion.zsh"
source_if_exists "$ZSH_CONFIG_DIR/plugins.zsh"
source_if_exists "$ZSH_CONFIG_DIR/env.zsh"
source_if_exists "$ZSH_CONFIG_DIR/tools.zsh"
