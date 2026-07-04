# On-demand SSH tunnel proxy — design

**Date:** 2026-07-04
**Status:** Approved (design phase)

## Problem

`zeus` and `home` are the same physical host, reached differently depending on
network location: directly on the LAN (`172.18.18.31`) when home, or via the
public endpoint (`home.chad-cat-lore-eddie.com:2222`) when away. Today the SSH
config forwards seven service ports through whichever host is chosen manually.
The goal is to stop choosing manually: a lightweight, always-listening proxy
should bring up the correct tunnel on demand, reuse it if one already exists,
and forward the service ports transparently.

## Behavior

For a given local port, when a client connects:

1. If a live SSH master to `zeus` exists, reuse it.
2. Else if a live SSH master to `home` exists, reuse it.
3. Else pick the host by network location: if this machine currently holds an
   address in `172.18.18.0/24`, use `zeus`; otherwise use `home`. Open the
   master.
4. Proxy the connection through that master to the remote service.

Checking for an existing master *before* the network test keeps every port
instance pinned to the same host and avoids redundant probing.

## Architecture

All artifacts live in the stow-managed dotfiles repo.

### `.local/bin/ssh-tunnel-proxy` (bash)

A single script with three subcommands:

- **`connect <port>`** — per-connection worker. Resolves the host (logic above),
  then `exec ssh -W 127.0.0.1:<port> -o ClearAllForwardings=yes <host>`. Invoked
  by socat with the accepted TCP socket wired to stdin/stdout, so ssh's `-W`
  channel *is* the proxy.
- **`listen <port>`** — long-lived listener for one port:
  `exec socat TCP-LISTEN:<port>,bind=127.0.0.1,reuseaddr,fork EXEC:"<self> connect <port>"`.
- **`start`** — launches `listen` for the seven hardcoded ports, installs a
  signal trap to tear down its children, and `wait`s so launchd supervises the
  whole group as one process.

Hardcoded ports: `1080 8080 7878 8006 8113 8989 9999`.

Local port N always maps to remote `127.0.0.1:N` (same-number, matching the
current forwards).

### Host selection details

```
pick_host():
  ssh -O check zeus 2>/dev/null && return zeus
  ssh -O check home 2>/dev/null && return home
  host = on_home_lan ? zeus : home
  flock <lockfile>:
    ssh -O check "$host" || ssh -MNf -o ClearAllForwardings=yes "$host"
  return host

on_home_lan():
  ifconfig | grep -qE 'inet 172\.18\.18\.'
```

- **Existing-tunnel detection** relies on the SSH `ControlMaster`/`ControlPath`
  already configured in the `Host *` block
  (`ControlPath ~/.ssh/ssh_mux_%h_%p_%r`, `ControlPersist 900`). Because the
  path includes `%h`, `zeus` and `home` have distinct sockets, so `ssh -O check`
  both detects a live tunnel and identifies which host it is.
- **flock** around the dial prevents several simultaneous first-connections
  (across the seven ports) from racing to open duplicate masters.
- **`ClearAllForwardings=yes`** is defensive: with `LocalForward` lines removed
  from the config (below), the master carries no forwards anyway, but the flag
  guarantees the proxy never tries to bind the very ports it is listening on
  even if the config regains forwards later.

### `Library/LaunchAgents/com.chad.ssh-tunnel-proxy.plist`

Stows to `~/Library/LaunchAgents/`. Runs `~/.local/bin/ssh-tunnel-proxy start`
with `RunAtLoad` and `KeepAlive` (start at login, restart the group if it
exits). stdout/stderr logged under `~/.local/var/log/`.

macOS-only. The core script and its subcommands remain portable to Linux; only
the launchd supervision is platform-specific.

## SSH config change

Remove the seven `LocalForward` lines from the shared `Host zeus home` block.
The proxy becomes the single source of port forwarding; manual `ssh zeus` /
`ssh home` become plain shells. After the change the shared block is just:

```
Host zeus home
    User chad
    IdentityFile ~/.ssh/zeus.pub
```

## Data flow

```
app → 127.0.0.1:8080
    → socat (fork per connection)
    → ssh-tunnel-proxy connect 8080
    → ssh -W over the shared ControlMaster
    → remote 127.0.0.1:8080
```

## Error handling

- **socat / ssh not installed:** `start` and `connect` check for both up front
  and exit with a clear message (`brew install socat`).
- **Master dial fails** (host unreachable): `ssh -MNf` returns non-zero; the
  `connect` worker exits, socat closes the client socket. The next connection
  retries — including re-running network detection, so a location change is
  picked up.
- **Stale control socket:** `ssh -O check` reports a dead master as absent, so
  selection falls through to opening a fresh one.
- **Concurrent first-connections:** serialized by flock; losers re-check and
  reuse the winner's master.

## Testing

- `on_home_lan` returns true on `172.18.18.0/24`, false otherwise (mockable by
  stubbing `ifconfig` output).
- `pick_host` prefers a live master over network detection; picks `zeus` on-LAN
  and `home` off-LAN when no master exists (stub `ssh -O check` and
  `on_home_lan`).
- `connect` execs `ssh -W` with the right target port and host.
- End-to-end: start a listener on a spare port, connect, confirm bytes reach the
  expected remote service and the master is reused on a second connection.

## Out of scope (YAGNI)

- Per-port remote-target overrides / config file (ports hardcoded).
- Linux supervision (systemd unit) — launchd only for now.
- Routing by anything other than own-LAN membership.
