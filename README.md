# dotfiles
Home directory replication

Steps to setup:
1. install gnu stow like `brew install stow`
2. install a nerdfont https://www.nerdfonts.com/font-downloads
3. install oh-my-posh like `brew install oh-my-posh`
4. clone repo and submodules to ~/dotfiles
5. `cd ~/dotfiles; ./deploy.sh`

Use `./deploy.sh` rather than `stow .` directly — besides stowing, it links the
1Password SSH agent socket and reloads the launchd agent (see below). Running
bare `stow .` leaves both undone. It is idempotent, so re-run it after pulling.

## 1Password SSH agent

`.ssh/config` sets `IdentityAgent ~/.1password/agent.sock` on macOS, and
`.zprofile` points `SSH_AUTH_SOCK` at the same place. That short path is a
symlink to the real socket under `~/Library/Group Containers/`, created by
`deploy.sh` on macOS. It is deliberately not tracked in the repo: the target
exists only on macOS, so a committed symlink would deploy a dead path on Linux.

Symptom of a missing or stale link: `ssh-add -l` reports "Error connecting to
agent" and every key-based `ssh` fails, even though 1Password is running. Fix
by re-running `./deploy.sh`.

## SSH tunnel proxy

`~/.local/bin/ssh-tunnel-proxy` lazily forwards a couple of ports to the home
server, auto-picking `zeus` (on the home LAN) or `home` (remote) per
connection and reusing a live SSH primary (ControlMaster) if one exists. It
replaces the manual `LocalForward` lines that used to live in `.ssh/config`.

- Supervised by `~/Library/LaunchAgents/com.chad.ssh-tunnel-proxy.plist`
  (loads at login, restarts on exit).
- Ports: 1080 (SOCKS) and 8113 (qBittorrent WebUI API — tunneled because the
  public host is behind Authelia, which `qbt` cannot authenticate through).
  Everything else is reached directly and is no longer tunneled.
- Manual run: `ssh-tunnel-proxy start`. Logs: `/tmp/ssh-tunnel-proxy.{out,err}.log`.
- Requires `socat` (`brew install socat`).
