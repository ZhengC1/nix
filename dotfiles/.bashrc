# History
HISTCONTROL=ignoredups:ignorespace
HISTSIZE=10000
HISTFILESIZE=20000
shopt -s histappend

# Aliases
alias ls='ls --color=auto'
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

# Auto-attach to tmux if not already inside a session
if command -v tmux &>/dev/null && [ -n "$PS1" ] && \
   [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && \
   [ -z "$TMUX" ]; then
  exec tmux
fi

# Tool integrations (only init if the tool is available)
command -v starship  &>/dev/null && eval "$(starship init bash)"
command -v zoxide    &>/dev/null && eval "$(zoxide init bash)"
command -v direnv    &>/dev/null && eval "$(direnv hook bash)"
[ -f ~/.fzf.bash ] && source ~/.fzf.bash
