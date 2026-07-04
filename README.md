# dotfiles
Home directory replication

Steps to setup:
1. install gnu stow like `brew install stow`
2. install a nerdfont https://www.nerdfonts.com/font-downloads
3. install oh-my-posh like `brew install oh-my-posh`
4. clone repo and submodules to ~/dotfiles
5. cd ~/dotfiles; stow .

## SSH tunnel proxy

`~/.local/bin/ssh-tunnel-proxy` lazily forwards service ports to the home
server, auto-picking `zeus` (on the home LAN) or `home` (remote) per
connection and reusing a live SSH primary (ControlMaster) if one exists. It
replaces the manual `LocalForward` lines that used to live in `.ssh/config`.

- Supervised by `~/Library/LaunchAgents/com.chad.ssh-tunnel-proxy.plist`
  (loads at login, restarts on exit).
- Ports: 1080 8080 7878 8006 8113 8989 9999.
- Manual run: `ssh-tunnel-proxy start`. Logs: `/tmp/ssh-tunnel-proxy.{out,err}.log`.
- Requires `socat` (`brew install socat`).
