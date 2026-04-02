autoload -Uz compinit
compinit

export PATH="$HOME/.local/bin:$PATH"
. "$HOME/.local/bin/env"

export PATH="$HOME/.pixi/bin:$PATH"

if [ -f ~/.zsh_aliases ]; then
    . ~/.zsh_aliases
fi
