if [ -e "/opt/homebrew/bin/brew" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# 1Password SSH agent socket. Set here (login shell) rather than .zshrc so it is
# available to non-interactive login shells too — notably the ssh-tunnel-proxy
# launchd agent, which runs `zsh -lc` and never sources .zshrc.
if [ -e "${HOME}/.1password/agent.sock" ]; then
    export SSH_AUTH_SOCK="${HOME}/.1password/agent.sock"
elif [ -e "${HOME}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock" ]; then
    export SSH_AUTH_SOCK="${HOME}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
fi
