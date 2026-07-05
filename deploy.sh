#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
stow --no-folding .

# (Re)load the ssh-tunnel-proxy launchd agent on macOS so plist changes take
# effect immediately; bootout || true makes the first run (not yet loaded) a no-op.
PLIST="$HOME/Library/LaunchAgents/com.chad.ssh-tunnel-proxy.plist"
if [[ "$(uname -s)" = "Darwin" && -e "$PLIST" ]]; then
  launchctl bootout  "gui/$(id -u)" "$PLIST" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$PLIST"
fi
