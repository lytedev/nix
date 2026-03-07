# ls aliases (using eza)
alias ls='eza --group-directories-first --classify'
alias l='ls'
alias ll='ls --long --group'
alias la='ll --all'
alias lA='la --all' # --all twice to show . and ..
alias tree='ls --tree --level=3'
alias lt='ll --sort=modified'
alias lat='la --sort=modified'
alias lta='lat'
alias lc='lt --sort=accessed'
alias lT='lt --reverse'
alias lC='lc --reverse'
alias lD='la --only-dirs'

# directory navigation
alias 'cd..'='d ..'
alias cdc='d $XDG_CONFIG_HOME'
alias cdn='d $NOTES_PATH'
alias cdl='d $XDG_DOWNLOAD_DIR'
alias cdg='d $XDG_GAMES_DIR'
alias '..'='d ..'
alias '...'='d ../..'
alias '....'='d ../../..'
alias '.....'='d ../../../..'
alias '......'='d ../../../../..'
alias '.......'='d ../../../../../..'
alias '........'='d ../../../../../../..'
alias '.........'='d ../../../../../../../..'

# system
alias disks='df -h && lsblk'
alias sctl='sudo systemctl'
alias sctlu='systemctl --user'
alias bt='bluetoothctl'
alias pa='pulsemixer'
alias pv='pavucontrol'

# tools
alias p='ping'
alias dc='docker compose'
alias pc='podman-compose'
alias k='kubectl'
alias kg='kubectl get'
alias v='$EDITOR'
alias sv='sudo $EDITOR'
alias kssh='kitty +kitten ssh'

# zellij
alias z='zellij'

# bat
alias cat='bat'
