# ~/.bash_profile

# Get the aliases and functions
if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi

# User specific environment and startup programs
[ -r "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
[ -r "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"
