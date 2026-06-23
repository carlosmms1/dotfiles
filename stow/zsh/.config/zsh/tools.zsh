# asdf shims
export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"

# Zoxide
eval "$(zoxide init zsh)"
alias cd="z"
