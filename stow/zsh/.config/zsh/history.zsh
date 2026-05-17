HISTSIZE=10000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase

setopt appendhistory        # Appends the current session's history to the history file when the shell exits, rather than overwriting it
setopt sharehistory         # Shares history across all active terminal sessions in real-time
setopt hist_ignore_space    # Prevent from saving commands that start with a space to history
setopt hist_ignore_all_dups # Delete old recorded entry if new entry is a duplicate
setopt hist_save_no_dups    # Do not write duplicate entries to the history file
setopt hist_find_no_dups    # Prevents the shell from displaying duplicate history entries
