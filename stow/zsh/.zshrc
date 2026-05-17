export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"

# Core Config Dir
ZSH_CONFIG_DIR="$HOME/.config/zsh"

# Ensure Core Config Dir Exists
[[ ! -d "$ZSH_CONFIG_DIR" ]] && mkdir -p "$ZSH_CONFIG_DIR"

# Load Config Modules
# Source modules
source_if_exists() {
	[[ -r "$1" ]] && source "$1"
}

# source_if_exists "$ZSH_CONFIG_DIR/history.zsh"
# source_if_exists "$ZSH_CONFIG_DIR/completion.zsh"
# source_if_exists "$ZSH_CONFIG_DIR/plugins.zsh"
# source_if_exists "$ZSH_CONFIG_DIR/env.zsh"
# source_if_exists "$ZSH_CONFIG_DIR/tools.zsh"

# Loop available zsh modules
for module in history completion plugins env tools; do
    [[ -r "$ZSH_CONFIG_DIR/$module.zsh" ]] && source "$ZSH_CONFIG_DIR/$module.zsh"
done

# Load Oh My Zsh
source $ZSH/oh-my-zsh.sh
