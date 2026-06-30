# Completions Settings
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# asdf completions
fpath=(${ASDF_DATA_DIR:-$HOME/.asdf}/completions $fpath)

autoload bashcompinit && bashcompinit
autoload -Uz compinit
compinit
