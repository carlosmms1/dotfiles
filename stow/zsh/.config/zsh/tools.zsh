# asdf shims
if [ -d "${ASDF_DATA_DIR:-$HOME/.asdf}" ]; then
  export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"
fi

if [ -d "/home/linuxbrew/.linuxbrew" ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"
fi

if [ -d "/home/.local/bin/uv" ]; then
  . "$HOME/.local/bin/env"
fi

if [ -d "/home/.cargo/bin" ]; then
  . "$HOME/.cargo/env" 
fi

# Zoxide
eval "$(zoxide init zsh)"
alias cd="z"
