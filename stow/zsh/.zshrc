# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="powerlevel10k/powerlevel10k"

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
for module in history env plugins tools completion aliases; do
    [[ -r "$ZSH_CONFIG_DIR/$module.zsh" ]] && source "$ZSH_CONFIG_DIR/$module.zsh"
done

# Load Oh My Zsh
source $ZSH/oh-my-zsh.sh

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# bun completions
[ -s "/home/cmms/.bun/_bun" ] && source "/home/cmms/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
