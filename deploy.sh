#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
# -R (restow) unstows before stowing. Plain `stow` only adds links, so a file
# deleted or renamed in the repo leaves its symlink behind in $HOME pointing at
# a path that no longer exists — that stale-link class has silently broken the
# 1Password agent socket, an old chadshost key, and others. Restowing removes
# links that point into this repo before recreating the current set.
stow -R --no-folding .

# Link 1Password's SSH agent socket to the short path that .ssh/config's
# IdentityAgent and .zprofile both expect. Created here rather than tracked in
# the repo: the target is macOS-only, and a committed symlink would deploy a
# dead path on Linux. -f replaces a stale link from an earlier layout.
if [[ "$(uname -s)" = "Darwin" ]]; then
  AGENT_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
  mkdir -p "$HOME/.1password"
  ln -sfn "$AGENT_SOCK" "$HOME/.1password/agent.sock"
fi

# (Re)load the ssh-tunnel-proxy launchd agent on macOS so plist changes take
# effect immediately; bootout || true makes the first run (not yet loaded) a no-op.
PLIST="$HOME/Library/LaunchAgents/com.chad.ssh-tunnel-proxy.plist"
if [[ "$(uname -s)" = "Darwin" && -e "$PLIST" ]]; then
  launchctl bootout  "gui/$(id -u)" "$PLIST" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$PLIST"
fi
