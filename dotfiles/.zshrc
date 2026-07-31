# History
HISTSIZE=10000
SAVEHIST=20000
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt APPEND_HISTORY

# Aliases
alias ls='ls -G'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias vim='nvim'
alias vi='nvim'
alias ..='cd ..'
alias ...='cd ../..'

# Environment
export EDITOR='nvim'
export VISUAL='nvim'

# Nix
if [ -d "$HOME/.nix-profile/bin" ]; then
  export PATH="$HOME/.nix-profile/bin:$PATH"
fi

# Auto-attach to tmux if not already inside a session
if command -v tmux &>/dev/null && [ -n "$PS1" ] && \
   [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && \
   [ -z "$TMUX" ]; then
  exec tmux
fi

# Tool integrations (only init if the tool is available)
command -v starship  &>/dev/null && eval "$(starship init zsh)"
command -v zoxide    &>/dev/null && eval "$(zoxide init zsh)"
command -v direnv    &>/dev/null && eval "$(direnv hook zsh)"
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
