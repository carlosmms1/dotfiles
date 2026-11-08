# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

# Core config dir (stowed from dotfiles/stow/zsh/.config/zsh)
ZSH_CONFIG_DIR="$HOME/.config/zsh"

source_if_exists() {
  [[ -r "$1" ]] && source "$1"
}

# Load modules before Oh My Zsh so `plugins` is defined when it starts.
for module in history env plugins tools completion aliases; do
  source_if_exists "$ZSH_CONFIG_DIR/$module.zsh"
done

# Load Oh My Zsh once.
if [[ -r "$ZSH/oh-my-zsh.sh" ]]; then
  source "$ZSH/oh-my-zsh.sh"
else
  print -u2 "oh-my-zsh não encontrado em $ZSH (rode ./setup.sh)"
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
source_if_exists "$HOME/.p10k.zsh"

# Bun
export BUN_INSTALL="$HOME/.bun"
if [[ -d "$BUN_INSTALL/bin" ]]; then
  case ":$PATH:" in
    *":$BUN_INSTALL/bin:"*) ;;
    *) export PATH="$BUN_INSTALL/bin:$PATH" ;;
  esac
fi
source_if_exists "$BUN_INSTALL/_bun"

# uv / pipx style local binaries
source_if_exists "$HOME/.local/bin/env"

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac

# opencode
if [[ -d "$HOME/.opencode/bin" ]]; then
  case ":$PATH:" in
    *":$HOME/.opencode/bin:"*) ;;
    *) export PATH="$HOME/.opencode/bin:$PATH" ;;
  esac
fi

# Local secrets (never committed). Preferred file first, legacy file second.
for env_file in "$HOME/.config/opencode/.env" "$HOME/.config/opencode/github-mcp.env"; do
  source_if_exists "$env_file"
done
unset env_file
