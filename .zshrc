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

export NVM_DIR="$HOME/.nvm"
if [ ! -d "${NVM_DIR}" ]; then
	curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.7/install.sh | bash
	source "${NVM_DIR}/nvm.sh"
	nvm install --lts
	nvm use system
fi

# SSH_AUTH_SOCK (1Password agent) is set in ~/.zprofile so login shells and the
# ssh-tunnel-proxy launchd agent get it too.

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
zstyle ':completion:*' special-dirs false
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

# Ensure socat is installed on macOS (required by ssh-tunnel-proxy)
if [[ "$(uname -s)" = "Darwin" ]] && ! command -v socat >/dev/null 2>&1; then
  brew install socat
fi

# qbt insists on reading credentials from a config file, so render one from
# 1Password into a named FIFO — the secrets stay off disk entirely. The .toml
# suffix is load-bearing: qbt uses Viper, which infers the format from the file
# extension and rejects an extensionless /dev/fd/N from `<(...)`. Without op
# installed the plain binary is used, so non-macOS boxes still work.
if command -v op >/dev/null 2>&1; then
  qbt() {
    local dir rc writer
    dir="$(mktemp -d)" || return 1
    if ! mkfifo -m 600 "$dir/.qbt.toml"; then
      rm -rf "$dir"
      return 1
    fi
    op inject -i "$HOME/.config/qbt/.qbt.toml.tpl" > "$dir/.qbt.toml" &
    writer=$!
    command qbt --config "$dir/.qbt.toml" "$@"
    rc=$?
    # If qbt exited before opening the FIFO, the writer is still blocked on it.
    kill "$writer" 2>/dev/null
    wait "$writer" 2>/dev/null
    rm -rf "$dir"
    return $rc
  }
fi

source ~/.env

# The following lines have been added by Docker Desktop to enable Docker CLI completions.
fpath=($HOME/.docker/completions $fpath)
autoload -Uz compinit
compinit
# End of Docker CLI completions
export PATH="/opt/homebrew/opt/node@24/bin:$PATH:${HOME}/.local/bin:${HOME}/go/bin"


# pnpm
export PNPM_HOME="/Users/cwalker/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

export PATH="$HOME/.local/bin:$PATH"

# OpenClaw Completion
[ -f "/Users/cwalker/.openclaw/completions/openclaw.zsh" ] && source "/Users/cwalker/.openclaw/completions/openclaw.zsh"
