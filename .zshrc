FZF_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/fzf"
if [ ! -d "$FZF_DIR" ]; then
    mkdir -p "$(dirname $FZF_DIR)"
    git clone --depth 1 https://github.com/junegunn/fzf.git "$FZF_DIR"
    $FZF_DIR/install --bin --xdg
fi

export PATH="$FZF_DIR/bin:${HOME}/.local/bin:$PATH"

ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
# Download zinit if it's not there
if [ ! -d "$ZINIT_HOME" ]; then
	mkdir -p "$(dirname $ZINIT_HOME)"
	git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

if [ -e "${HOME}/.1password/agent.sock" ]; then
    export SSH_AUTH_SOCK="${HOME}/.1password/agent.sock"
fi

# Source zinit
source "${ZINIT_HOME}/zinit.zsh"

export PATH="$HOME/.bin:$HOME/.fzf/bin:$HOME/.local/bin:$HOME/Developer/PlaydateSDK/bin:$PATH"

# zsh plugins
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

# snippets
zinit snippet OMZP::git
zinit snippet OMZP::sudo
zinit snippet OMZP::aws
zinit snippet OMZP::kubectl
zinit snippet OMZP::kubectx
zinit snippet OMZP::command-not-found

# load completions
autoload -U compinit && compinit

zinit cdreplay -q

eval "$(oh-my-posh init zsh --config ${HOME}/.config/oh-my-posh/kushal.omp.json)"

bindkey -e

# History
HISTSIZE=5000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# Completeions
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'

eval "$(fzf --zsh)"

# Aliases
[[ ! -f ~/.aliases ]] || source ~/.aliases

# Add VS Code binary to PATH on macOS
if [ -f '/Applications/Visual Studio Code.app/Contents/Resources/app/bin' ]; then PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"; fi

# The next line updates PATH for the Google Cloud SDK.
if [ -f "$HOME/google-cloud-sdk/path.zsh.inc" ]; then . "$HOME/google-cloud-sdk/path.zsh.inc"; fi

# The next line enables shell command completion for gcloud.
if [ -f "$HOME/google-cloud-sdk/completion.zsh.inc" ]; then . "$HOME/google-cloud-sdk/completion.zsh.inc"; fi

if [[ "$(uname -s)" = "Darwin" && -d "/opt/homebrew/opt/curl" ]]; then
  export PATH="/opt/homebrew/opt/curl/bin:$PATH"
  export LDFLAGS="-L/opt/homebrew/opt/curl/lib"
  export CPPFLAGS="-I/opt/homebrew/opt/curl/include"
fi

source ~/.env
