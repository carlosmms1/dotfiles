# asdf shims
if [ -d "${ASDF_DATA_DIR:-$HOME/.asdf}" ]; then
  export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"
fi

if [ -d "/home/linuxbrew/.linuxbrew" ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"
fi

# Zoxide
eval "$(zoxide init zsh)"
alias cd="z"
