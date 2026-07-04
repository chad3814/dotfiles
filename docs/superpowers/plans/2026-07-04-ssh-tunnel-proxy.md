# On-demand SSH Tunnel Proxy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a lazy, always-listening proxy that forwards seven local service ports over an SSH tunnel to `zeus`/`home`, auto-selecting the host per connection and reusing an existing tunnel when one is up.

**Architecture:** A single bash script (`ssh-tunnel-proxy`) exposes three subcommands. `listen <port>` runs a per-port `socat` listener that forks each connection into `connect <port>`, which resolves the target host and `exec`s `ssh -W`. Host resolution prefers a live `ControlMaster` (detected via `ssh -O check`, one socket per host) and falls back to LAN detection. `start` launches all seven listeners under one supervised process; a launchd agent keeps it running. Functions are written to be sourceable so they can be unit-tested with stubbed `ssh`/`ifconfig`/`socat`.

**Tech Stack:** bash, socat, OpenSSH (`-W`, `ControlMaster`, `-O check`), macOS launchd. No test framework — plain sourceable-bash unit tests with a tiny assert helper.

## Global Constraints

- Language: `bash` (`#!/usr/bin/env bash`, `set -euo pipefail` in the executed entrypoint only — NOT at top level, so sourcing for tests is safe).
- Dependencies limited to `ssh` and `socat`; no other runtime installs. `socat` is at `/opt/homebrew/bin/socat`, `ssh` at `/usr/bin/ssh`.
- Forwarded ports (hardcoded, same-number mapping local N → remote `127.0.0.1:N`): `1080 8080 7878 8006 8113 8989 9999`.
- Host order for existing-tunnel check: `zeus` then `home`.
- LAN test: this machine holds an address in `172.18.18.0/24` → `zeus`, else `home`.
- Every proxy `ssh` invocation carries `-o ClearAllForwardings=yes` (defensive; the config's `LocalForward` lines are removed in Task 9).
- Reuse the existing `ControlMaster`/`ControlPath ~/.ssh/ssh_mux_%h_%p_%r`/`ControlPersist 900` from the `Host *` block — do NOT add new primary options in the script beyond `ClearAllForwardings`.
- `flock` is unavailable on stock macOS, so serialization uses an atomic `mkdir` lock (achieves the spec's flock intent).
- Repo is stow-managed (root maps to `$HOME`); any new top-level dir that must NOT be symlinked into `$HOME` (e.g. `tests`) is added to `.stow-local-ignore`. `.local/bin` and `Library/LaunchAgents` ARE meant to be stowed.
- Per the user's global rule, **no git commit without the user's explicit approval.** The commit step in each task is the intended boundary; when executing, obtain approval (batch is fine) rather than committing unprompted.
- Match repo commit style: short, descriptive, imperative subject lines (no `feat:`/`fix:` prefixes).

---

## File Structure

- `.local/bin/ssh-tunnel-proxy` — the whole program (all subcommands + functions). Stows to `~/.local/bin/ssh-tunnel-proxy`.
- `tests/ssh-tunnel-proxy.test.sh` — sourceable-bash unit tests with an inline mini-harness.
- `Library/LaunchAgents/com.chad.ssh-tunnel-proxy.plist` — launchd agent. Stows to `~/Library/LaunchAgents/`.
- `.stow-local-ignore` — add `tests` (docs already added).
- `.ssh/config` — remove the seven `LocalForward` lines from the `Host zeus home` block.

---

### Task 1: Script scaffold, dispatch, and test harness

**Files:**
- Create: `.local/bin/ssh-tunnel-proxy`
- Create: `tests/ssh-tunnel-proxy.test.sh`
- Modify: `.stow-local-ignore` (add `tests`)

**Interfaces:**
- Consumes: nothing.
- Produces:
  - Sourceable script defining (initially empty-bodied where noted) `usage()`, `main()`, and globals `PORTS` (array), `HOSTS` (array), `SELF` (abs path). `_exec()` wrapper: `_exec() { exec "$@"; }`.
  - Sourcing the script must NOT run `main` (guard: `[[ "${BASH_SOURCE[0]}" == "${0}" ]]`).
  - `main <subcommand>` dispatches; unknown/empty subcommand prints usage to stderr and returns `2`.
  - Test harness: `assert_eq expected actual msg`, `assert_status expected_code msg` (checks `$?`... via explicit passing), `run_test fn`, `finish` (exits nonzero if any failure). Env `STP_LIB=1` is NOT needed; tests just `source` the script.

- [ ] **Step 1: Write the failing test**

Create `tests/ssh-tunnel-proxy.test.sh`:

```bash
#!/usr/bin/env bash
# Unit tests for ssh-tunnel-proxy. Run: bash tests/ssh-tunnel-proxy.test.sh
# Sources the script (which must not run main when sourced) and stubs
# ssh/socat/ifconfig/ip as shell functions to exercise pure logic.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$HERE/../.local/bin/ssh-tunnel-proxy"

# --- mini harness ---
_run=0; _fail=0
assert_eq() { # expected actual msg
  _run=$((_run+1))
  if [[ "$1" == "$2" ]]; then echo "ok   - $3"
  else _fail=$((_fail+1)); echo "FAIL - $3: expected [$1] got [$2]"; fi
}
assert_true() { # status msg  (status 0 = pass)
  _run=$((_run+1))
  if [[ "$1" -eq 0 ]]; then echo "ok   - $2"
  else _fail=$((_fail+1)); echo "FAIL - $2: expected success got status $1"; fi
}
assert_false() { # status msg  (nonzero = pass)
  _run=$((_run+1))
  if [[ "$1" -ne 0 ]]; then echo "ok   - $2"
  else _fail=$((_fail+1)); echo "FAIL - $2: expected failure got status 0"; fi
}
finish() { echo "---"; echo "$_run run, $_fail failed"; [[ $_fail -eq 0 ]]; }

# Source under test.
# shellcheck source=/dev/null
source "$SCRIPT"

# --- Task 1 tests ---
test_sourcing_does_not_run_main() {
  # If sourcing ran main with no args it would have exited nonzero already;
  # reaching here at all is the assertion. Also confirm dispatch is a function.
  assert_eq "function" "$(type -t main)" "main is defined"
  assert_eq "function" "$(type -t usage)" "usage is defined"
}
test_unknown_subcommand_returns_2() {
  main bogus >/dev/null 2>&1; assert_eq 2 "$?" "unknown subcommand -> 2"
}
test_ports_hardcoded() {
  assert_eq "1080 8080 7878 8006 8113 8989 9999" "${PORTS[*]}" "seven ports"
}

run_all() {
  test_sourcing_does_not_run_main
  test_unknown_subcommand_returns_2
  test_ports_hardcoded
}
run_all
finish
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/ssh-tunnel-proxy.test.sh`
Expected: FAIL — `source: no such file` or (once file exists) failures because `main`/`PORTS` undefined.

- [ ] **Step 3: Write minimal implementation**

Create `.local/bin/ssh-tunnel-proxy`:

```bash
#!/usr/bin/env bash
# ssh-tunnel-proxy — lazy, host-auto-selecting SSH port proxy.
# Subcommands: listen <port> | connect <port> | start
# Sourceable: defining functions must not trigger main (see guard at bottom).

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
PORTS=(1080 8080 7878 8006 8113 8989 9999)
HOSTS=(zeus home)

# Indirection point so tests can capture the final command instead of exec'ing.
_exec() { exec "$@"; }

usage() {
  cat >&2 <<EOF
usage: ${0##*/} <listen|connect|start> [port]
  listen <port>   run a socat listener on 127.0.0.1:<port>
  connect <port>  resolve host and proxy stdin/stdout via ssh -W (used by socat)
  start           run listeners for all forwarded ports
EOF
}

main() {
  local sub="${1:-}"
  [[ $# -gt 0 ]] && shift
  case "$sub" in
    listen)  cmd_listen "$@" ;;
    connect) cmd_connect "$@" ;;
    start)   cmd_start "$@" ;;
    *)       usage; return 2 ;;
  esac
}

# Placeholder bodies filled in later tasks; declared so `main` dispatch resolves.
cmd_listen()  { usage; return 2; }
cmd_connect() { usage; return 2; }
cmd_start()   { usage; return 2; }

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail
  main "$@"
fi
```

Make it executable:

```bash
chmod +x .local/bin/ssh-tunnel-proxy
```

- [ ] **Step 4: Add `tests` to `.stow-local-ignore`**

Append a line so the test dir is not symlinked into `$HOME`. Resulting file:

```
deploy.sh
.git
LICENSE
README.md
docs
tests
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bash tests/ssh-tunnel-proxy.test.sh`
Expected: PASS — `3 run, 0 failed` (only the Task 1 tests exist so far).

- [ ] **Step 6: Commit**

```bash
git add .local/bin/ssh-tunnel-proxy tests/ssh-tunnel-proxy.test.sh .stow-local-ignore
git commit -m "Scaffold ssh-tunnel-proxy script and test harness"
```

---

### Task 2: LAN detection (`on_home_lan`)

**Files:**
- Modify: `.local/bin/ssh-tunnel-proxy`
- Modify: `tests/ssh-tunnel-proxy.test.sh`

**Interfaces:**
- Consumes: nothing.
- Produces: `on_home_lan()` → returns 0 if any local interface holds an address matching `172.18.18.<n>`, else 1. Reads from `ifconfig` then `ip -o addr show` (whichever exists); both stubbed in tests.

- [ ] **Step 1: Write the failing test**

Add to `tests/ssh-tunnel-proxy.test.sh` before `run_all`:

```bash
# --- Task 2 tests ---
test_on_home_lan_true() {
  ifconfig() { echo "	inet 172.18.18.145 netmask 0xffffff00 broadcast 172.18.18.255"; }
  ip() { :; }
  on_home_lan; assert_true "$?" "on_home_lan true when 172.18.18.x present"
  unset -f ifconfig ip
}
test_on_home_lan_false() {
  ifconfig() { echo "	inet 10.0.0.5 netmask 0xffffff00 broadcast 10.0.0.255"; }
  ip() { :; }
  on_home_lan; assert_false "$?" "on_home_lan false when not on 172.18.18.x"
  unset -f ifconfig ip
}
test_on_home_lan_no_false_positive_on_180() {
  ifconfig() { echo "	inet 172.18.180.5 netmask 0xffffff00"; }
  ip() { :; }
  on_home_lan; assert_false "$?" "172.18.180.x is not 172.18.18.x"
  unset -f ifconfig ip
}
```

And add to `run_all`:

```bash
  test_on_home_lan_true
  test_on_home_lan_false
  test_on_home_lan_no_false_positive_on_180
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/ssh-tunnel-proxy.test.sh`
Expected: FAIL — `on_home_lan: command not found` / status failures.

- [ ] **Step 3: Write minimal implementation**

In `.local/bin/ssh-tunnel-proxy`, add above the placeholder `cmd_*` block:

```bash
on_home_lan() {
  { ifconfig 2>/dev/null; ip -o addr show 2>/dev/null; } \
    | grep -qE '172\.18\.18\.[0-9]'
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/ssh-tunnel-proxy.test.sh`
Expected: PASS — `6 run, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add .local/bin/ssh-tunnel-proxy tests/ssh-tunnel-proxy.test.sh
git commit -m "Add home-LAN detection to ssh-tunnel-proxy"
```

---

### Task 3: Atomic mkdir lock (`with_lock`)

**Files:**
- Modify: `.local/bin/ssh-tunnel-proxy`
- Modify: `tests/ssh-tunnel-proxy.test.sh`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - Global `STP_LOCKDIR="${STP_LOCKDIR:-${TMPDIR:-/tmp}/ssh-tunnel-proxy.lock.d}"` (env-overridable for tests).
  - `with_lock <cmd...>` → acquires the lock (spins on `mkdir "$STP_LOCKDIR"` up to ~50 tries × 0.1s), runs `"$@"`, releases via `rmdir`, and returns the command's exit status. Releases the lock even if the command fails.

- [ ] **Step 1: Write the failing test**

Add before `run_all`:

```bash
# --- Task 3 tests ---
test_with_lock_runs_command_and_returns_status() {
  STP_LOCKDIR="$(mktemp -d)/lock.d"
  with_lock true; assert_true "$?" "with_lock passes through success"
  with_lock false; assert_false "$?" "with_lock passes through failure"
}
test_with_lock_releases_lock() {
  STP_LOCKDIR="$(mktemp -d)/lock.d"
  with_lock true
  [[ -d "$STP_LOCKDIR" ]]; assert_false "$?" "lock dir removed after run"
}
test_with_lock_serializes() {
  STP_LOCKDIR="$(mktemp -d)/lock.d"
  mkdir -p "$STP_LOCKDIR"   # pre-hold the lock
  ( sleep 0.3; rmdir "$STP_LOCKDIR" ) &
  with_lock true; assert_true "$?" "with_lock waits then acquires"
  wait
}
```

Add to `run_all`:

```bash
  test_with_lock_runs_command_and_returns_status
  test_with_lock_releases_lock
  test_with_lock_serializes
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/ssh-tunnel-proxy.test.sh`
Expected: FAIL — `with_lock: command not found`.

- [ ] **Step 3: Write minimal implementation**

Add near the top of `.local/bin/ssh-tunnel-proxy` (after `HOSTS=`):

```bash
STP_LOCKDIR="${STP_LOCKDIR:-${TMPDIR:-/tmp}/ssh-tunnel-proxy.lock.d}"

with_lock() {
  local tries=0
  until mkdir "$STP_LOCKDIR" 2>/dev/null; do
    tries=$((tries+1))
    if (( tries >= 50 )); then
      # Give up waiting; run without the lock rather than hang forever.
      break
    fi
    sleep 0.1
  done
  local status=0
  "$@" || status=$?
  rmdir "$STP_LOCKDIR" 2>/dev/null || true
  return "$status"
}
```

Note: `STP_LOCKDIR` is read at each `with_lock` call via the global, so tests that reassign it before calling take effect.

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/ssh-tunnel-proxy.test.sh`
Expected: PASS — `9 run, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add .local/bin/ssh-tunnel-proxy tests/ssh-tunnel-proxy.test.sh
git commit -m "Add atomic mkdir lock helper to ssh-tunnel-proxy"
```

---

### Task 4: Primary detection and dial (`primary_alive`, `ensure_primary`)

**Files:**
- Modify: `.local/bin/ssh-tunnel-proxy`
- Modify: `tests/ssh-tunnel-proxy.test.sh`

**Interfaces:**
- Consumes: `with_lock` (Task 3).
- Produces:
  - `primary_alive <host>` → 0 iff `ssh -O check <host>` succeeds.
  - `ensure_primary <host>` → if no live primary, dials one with `ssh -MNf -o ClearAllForwardings=yes <host>`, serialized by `with_lock` and re-checking inside the lock. Returns 0 on a live/started primary.

- [ ] **Step 1: Write the failing test**

Add before `run_all`:

```bash
# --- Task 4 tests ---
test_primary_alive_reflects_ssh_check() {
  ssh() { [[ "$*" == "-O check zeus" ]] && return 0; return 1; }
  primary_alive zeus; assert_true "$?" "primary_alive true when ssh -O check ok"
  primary_alive home; assert_false "$?" "primary_alive false when ssh -O check fails"
  unset -f ssh
}
test_ensure_primary_dials_when_absent() {
  STP_LOCKDIR="$(mktemp -d)/lock.d"
  STP_TEST_DIALED=""
  ssh() {
    case "$*" in
      "-O check "*) return 1 ;;                       # no primary yet
      "-MNf -o ClearAllForwardings=yes zeus")
        STP_TEST_DIALED=zeus; return 0 ;;
      *) return 1 ;;
    esac
  }
  ensure_primary zeus; assert_true "$?" "ensure_primary returns ok after dial"
  assert_eq "zeus" "$STP_TEST_DIALED" "ensure_primary dialed zeus"
  unset -f ssh
}
test_ensure_primary_skips_dial_when_present() {
  STP_LOCKDIR="$(mktemp -d)/lock.d"
  STP_TEST_DIALED=""
  ssh() {
    case "$*" in
      "-O check "*) return 0 ;;                        # already alive
      "-MNf "*) STP_TEST_DIALED=yes; return 0 ;;
      *) return 1 ;;
    esac
  }
  ensure_primary zeus; assert_true "$?" "ensure_primary ok when already alive"
  assert_eq "" "$STP_TEST_DIALED" "ensure_primary did not re-dial"
  unset -f ssh
}
```

Add to `run_all`:

```bash
  test_primary_alive_reflects_ssh_check
  test_ensure_primary_dials_when_absent
  test_ensure_primary_skips_dial_when_present
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/ssh-tunnel-proxy.test.sh`
Expected: FAIL — `primary_alive: command not found`.

- [ ] **Step 3: Write minimal implementation**

Add to `.local/bin/ssh-tunnel-proxy` (after `on_home_lan`):

```bash
primary_alive() {
  ssh -O check "$1" >/dev/null 2>&1
}

_dial_primary() {
  local host="$1"
  primary_alive "$host" && return 0
  ssh -MNf -o ClearAllForwardings=yes "$host"
}

ensure_primary() {
  with_lock _dial_primary "$1"
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/ssh-tunnel-proxy.test.sh`
Expected: PASS — `15 run, 0 failed` (three assertions in the dial tests count individually: 15 total).

- [ ] **Step 5: Commit**

```bash
git add .local/bin/ssh-tunnel-proxy tests/ssh-tunnel-proxy.test.sh
git commit -m "Add SSH primary detection and dial to ssh-tunnel-proxy"
```

---

### Task 5: Host resolution (`resolve_host`) — the core decision

**Files:**
- Modify: `.local/bin/ssh-tunnel-proxy`
- Modify: `tests/ssh-tunnel-proxy.test.sh`

**Interfaces:**
- Consumes: `primary_alive`, `on_home_lan`, `ensure_primary`.
- Produces: `resolve_host()` → prints exactly `zeus` or `home` on stdout. Preference: live zeus primary → live home primary → LAN test (`zeus` on-LAN, else `home`), dialing the chosen primary before printing.

- [ ] **Step 1: Write the failing test**

Add before `run_all`:

```bash
# --- Task 5 tests ---
test_resolve_prefers_live_zeus() {
  primary_alive() { [[ "$1" == zeus ]]; }         # zeus up
  on_home_lan() { return 1; }                    # would say home
  ensure_primary() { return 0; }
  assert_eq "zeus" "$(resolve_host)" "live zeus primary wins"
  unset -f primary_alive on_home_lan ensure_primary
}
test_resolve_prefers_live_home_over_lan() {
  primary_alive() { [[ "$1" == home ]]; }         # home up, zeus down
  on_home_lan() { return 0; }                    # LAN would say zeus
  ensure_primary() { return 0; }
  assert_eq "home" "$(resolve_host)" "live home primary wins over LAN"
  unset -f primary_alive on_home_lan ensure_primary
}
test_resolve_lan_picks_zeus_and_dials() {
  primary_alive() { return 1; }                   # nothing up
  on_home_lan() { return 0; }                    # on LAN
  STP_TEST_ENSURED=""
  ensure_primary() { STP_TEST_ENSURED="$1"; return 0; }
  assert_eq "zeus" "$(resolve_host)" "no primary + LAN -> zeus"
  # resolve_host runs ensure_primary in the same shell only via command sub,
  # so re-run capturing the side effect directly:
  resolve_host >/dev/null
  assert_eq "zeus" "$STP_TEST_ENSURED" "dialed zeus primary"
  unset -f primary_alive on_home_lan ensure_primary
}
test_resolve_offlan_picks_home() {
  primary_alive() { return 1; }
  on_home_lan() { return 1; }                    # off LAN
  ensure_primary() { return 0; }
  assert_eq "home" "$(resolve_host)" "no primary + off-LAN -> home"
  unset -f primary_alive on_home_lan ensure_primary
}
```

Add to `run_all`:

```bash
  test_resolve_prefers_live_zeus
  test_resolve_prefers_live_home_over_lan
  test_resolve_lan_picks_zeus_and_dials
  test_resolve_offlan_picks_home
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/ssh-tunnel-proxy.test.sh`
Expected: FAIL — `resolve_host: command not found`.

- [ ] **Step 3: Write minimal implementation**

Add to `.local/bin/ssh-tunnel-proxy` (after `ensure_primary`):

```bash
resolve_host() {
  local h
  for h in "${HOSTS[@]}"; do
    if primary_alive "$h"; then
      printf '%s\n' "$h"
      return 0
    fi
  done
  if on_home_lan; then h=zeus; else h=home; fi
  ensure_primary "$h"
  printf '%s\n' "$h"
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/ssh-tunnel-proxy.test.sh`
Expected: PASS — `20 run, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add .local/bin/ssh-tunnel-proxy tests/ssh-tunnel-proxy.test.sh
git commit -m "Add host resolution logic to ssh-tunnel-proxy"
```

---

### Task 6: `connect` subcommand (proxy handoff)

**Files:**
- Modify: `.local/bin/ssh-tunnel-proxy`
- Modify: `tests/ssh-tunnel-proxy.test.sh`

**Interfaces:**
- Consumes: `resolve_host`, `_exec`.
- Produces: `cmd_connect <port>` → calls `_exec ssh -W 127.0.0.1:<port> -o ClearAllForwardings=yes <resolved-host>`. Returns 2 if `port` missing.

- [ ] **Step 1: Write the failing test**

Add before `run_all`:

```bash
# --- Task 6 tests ---
test_connect_builds_ssh_w_command() {
  resolve_host() { echo zeus; }
  _exec() { echo "$*"; }                # capture instead of exec
  local out; out="$(cmd_connect 8080)"
  assert_eq "ssh -W 127.0.0.1:8080 -o ClearAllForwardings=yes zeus" "$out" \
    "connect execs ssh -W to resolved host"
  unset -f resolve_host _exec
}
test_connect_requires_port() {
  cmd_connect >/dev/null 2>&1; assert_eq 2 "$?" "connect without port -> 2"
}
```

Add to `run_all`:

```bash
  test_connect_builds_ssh_w_command
  test_connect_requires_port
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/ssh-tunnel-proxy.test.sh`
Expected: FAIL — the placeholder `cmd_connect` prints usage/returns 2 for the port case, so the first assertion fails on output mismatch.

- [ ] **Step 3: Write minimal implementation**

In `.local/bin/ssh-tunnel-proxy`, replace the placeholder `cmd_connect() { usage; return 2; }` with:

```bash
cmd_connect() {
  local port="${1:-}"
  [[ -n "$port" ]] || { usage; return 2; }
  _exec ssh -W "127.0.0.1:$port" -o ClearAllForwardings=yes "$(resolve_host)"
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/ssh-tunnel-proxy.test.sh`
Expected: PASS — `22 run, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add .local/bin/ssh-tunnel-proxy tests/ssh-tunnel-proxy.test.sh
git commit -m "Add connect subcommand to ssh-tunnel-proxy"
```

---

### Task 7: `listen` and `start` subcommands

**Files:**
- Modify: `.local/bin/ssh-tunnel-proxy`
- Modify: `tests/ssh-tunnel-proxy.test.sh`

**Interfaces:**
- Consumes: `SELF`, `PORTS`, `_exec`.
- Produces:
  - `cmd_listen <port>` → `_exec socat TCP-LISTEN:<port>,bind=127.0.0.1,reuseaddr,fork EXEC:"<SELF> connect <port>"`. Returns 2 if port missing.
  - `require_cmds()` → 0 iff both `ssh` and `socat` are on PATH; else prints an error to stderr and returns 1.
  - `cmd_start()` → `require_cmds` (return 1 on failure), then launch `"$SELF" listen <port>` for each port in background, install an EXIT/INT/TERM trap that kills the children, and `wait`.

- [ ] **Step 1: Write the failing test**

Add before `run_all`:

```bash
# --- Task 7 tests ---
test_listen_builds_socat_command() {
  SELF=/fake/ssh-tunnel-proxy
  _exec() { echo "$*"; }
  local out; out="$(cmd_listen 8080)"
  assert_eq \
    "socat TCP-LISTEN:8080,bind=127.0.0.1,reuseaddr,fork EXEC:/fake/ssh-tunnel-proxy connect 8080" \
    "$out" "listen execs socat with EXEC back-reference"
  unset -f _exec
}
test_listen_requires_port() {
  cmd_listen >/dev/null 2>&1; assert_eq 2 "$?" "listen without port -> 2"
}
test_require_cmds_fails_when_socat_missing() {
  command() { if [[ "$*" == "-v socat" ]]; then return 1; fi; builtin command "$@"; }
  require_cmds >/dev/null 2>&1; assert_false "$?" "require_cmds fails w/o socat"
  unset -f command
}
test_start_bails_when_deps_missing() {
  require_cmds() { return 1; }
  cmd_start >/dev/null 2>&1; assert_false "$?" "start returns nonzero w/o deps"
  unset -f require_cmds
}
```

Add to `run_all`:

```bash
  test_listen_builds_socat_command
  test_listen_requires_port
  test_require_cmds_fails_when_socat_missing
  test_start_bails_when_deps_missing
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/ssh-tunnel-proxy.test.sh`
Expected: FAIL — placeholder `cmd_listen` output mismatch; `require_cmds` undefined.

- [ ] **Step 3: Write minimal implementation**

Replace the placeholder `cmd_listen`/`cmd_start` with real implementations and add `require_cmds`:

```bash
require_cmds() {
  local missing=0 c
  for c in ssh socat; do
    if ! command -v "$c" >/dev/null 2>&1; then
      echo "ssh-tunnel-proxy: required command not found: $c" >&2
      missing=1
    fi
  done
  return "$missing"
}

cmd_listen() {
  local port="${1:-}"
  [[ -n "$port" ]] || { usage; return 2; }
  _exec socat "TCP-LISTEN:$port,bind=127.0.0.1,reuseaddr,fork" \
    "EXEC:$SELF connect $port"
}

cmd_start() {
  require_cmds || return 1
  local pids=() port
  # shellcheck disable=SC2064
  trap 'kill "${pids[@]}" 2>/dev/null' EXIT INT TERM
  for port in "${PORTS[@]}"; do
    "$SELF" listen "$port" &
    pids+=("$!")
  done
  wait
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/ssh-tunnel-proxy.test.sh`
Expected: PASS — `26 run, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add .local/bin/ssh-tunnel-proxy tests/ssh-tunnel-proxy.test.sh
git commit -m "Add listen and start subcommands to ssh-tunnel-proxy"
```

---

### Task 8: launchd agent

**Files:**
- Create: `Library/LaunchAgents/com.chad.ssh-tunnel-proxy.plist`

**Interfaces:**
- Consumes: `~/.local/bin/ssh-tunnel-proxy start`.
- Produces: a user LaunchAgent that runs the proxy at login and restarts it if it exits.

- [ ] **Step 1: Write the plist**

Create `Library/LaunchAgents/com.chad.ssh-tunnel-proxy.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.chad.ssh-tunnel-proxy</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>-lc</string>
    <string>exec "$HOME/.local/bin/ssh-tunnel-proxy" start</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>/tmp/ssh-tunnel-proxy.out.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/ssh-tunnel-proxy.err.log</string>
</dict>
</plist>
```

Rationale for `/bin/bash -lc`: a login shell resolves `$HOME` and PATH (so `socat` in `/opt/homebrew/bin` is found) without hardcoding the homebrew path in the plist.

- [ ] **Step 2: Validate the plist parses**

Run: `plutil -lint Library/LaunchAgents/com.chad.ssh-tunnel-proxy.plist`
Expected: `... OK`

- [ ] **Step 3: Commit**

```bash
git add Library/LaunchAgents/com.chad.ssh-tunnel-proxy.plist
git commit -m "Add launchd agent for ssh-tunnel-proxy"
```

---

### Task 9: Remove now-redundant LocalForward lines from ssh config

**Files:**
- Modify: `.ssh/config`

**Interfaces:**
- Consumes: nothing.
- Produces: `zeus`/`home` blocks with no `LocalForward` lines; the proxy is the sole forwarder.

- [ ] **Step 1: Confirm current shared block**

Run: `grep -n "LocalForward" .ssh/config`
Expected: seven lines, all inside the `Host zeus home` block.

- [ ] **Step 2: Remove the LocalForward lines**

Edit `.ssh/config` so the shared block becomes exactly:

```
# Shared settings for both. The ssh-tunnel-proxy now owns port forwarding;
# see .local/bin/ssh-tunnel-proxy.
Host zeus home
    User chad
    IdentityFile ~/.ssh/zeus.pub
```

(Delete the seven `LocalForward 1080/8080/7878/8006/8113/8989/9999` lines.)

- [ ] **Step 3: Verify config still resolves for both hosts**

Run: `ssh -F .ssh/config -G zeus | grep -c '^localforward '; ssh -F .ssh/config -G home | grep -c '^localforward '`
Expected: `0` and `0` (no forwards left); hostnames/ports otherwise unchanged.

- [ ] **Step 4: Commit**

```bash
git add .ssh/config
git commit -m "Remove LocalForwards from zeus/home; ssh-tunnel-proxy owns them"
```

---

### Task 10: End-to-end verification and install notes

**Files:**
- Modify: `README.md` (append a short "SSH tunnel proxy" section)

**Interfaces:**
- Consumes: everything above.
- Produces: a documented, manually verified install path.

- [ ] **Step 1: Full unit suite green**

Run: `bash tests/ssh-tunnel-proxy.test.sh`
Expected: `26 run, 0 failed`.

- [ ] **Step 2: Live smoke test on a scratch port**

With you currently on the home LAN (so `zeus` is chosen), verify a real proxied connection to a known remote service. Pick a port the remote actually serves (e.g. 8080) but listen locally on a scratch port to avoid clashing with anything:

Run (foreground, then Ctrl-C):
```bash
# terminal A: listen on scratch local port 18080, proxying to remote :8080
STP_LOCKDIR=/tmp/stp.test.d ./.local/bin/ssh-tunnel-proxy listen 18080 &
LISTEN_PID=$!
sleep 1
# terminal A: hit it
curl -sS -m 5 http://127.0.0.1:18080/ -o /dev/null -w '%{http_code}\n' || true
# confirm a primary came up and identifies the host
ssh -O check zeus && echo "zeus primary up"
kill "$LISTEN_PID" 2>/dev/null
```
Expected: an HTTP status code (any response proves bytes traversed the tunnel), and `zeus primary up`. Note: this exercises `listen`→`connect`→`resolve_host`→`ssh -W`.

- [ ] **Step 3: Verify tunnel reuse (no second dial)**

Run:
```bash
ssh -O check zeus && echo "still up (reused)"
```
Expected: `still up (reused)` — the second connection reused the primary rather than dialing again.

- [ ] **Step 4: Deploy the symlinks and load the agent**

Run:
```bash
cd ~/dotfiles && ./deploy.sh          # stow symlinks (script + plist)
launchctl unload ~/Library/LaunchAgents/com.chad.ssh-tunnel-proxy.plist 2>/dev/null || true
launchctl load  ~/Library/LaunchAgents/com.chad.ssh-tunnel-proxy.plist
sleep 1
launchctl list | grep com.chad.ssh-tunnel-proxy
```
Expected: a line showing the agent loaded (PID or last-exit 0).

- [ ] **Step 5: Confirm all seven ports are listening**

Run: `for p in 1080 8080 7878 8006 8113 8989 9999; do nc -z 127.0.0.1 "$p" && echo "$p open"; done`
Expected: each port reported `open` (socat is bound; a connection would trigger the tunnel).

- [ ] **Step 6: Document it**

Append to `README.md`:

```markdown
## SSH tunnel proxy

`~/.local/bin/ssh-tunnel-proxy` lazily forwards service ports to the home
server, auto-picking `zeus` (on the home LAN) or `home` (remote) per
connection and reusing a live SSH primary if one exists. It replaces the
manual `LocalForward` lines that used to live in `.ssh/config`.

- Supervised by `~/Library/LaunchAgents/com.chad.ssh-tunnel-proxy.plist`
  (loads at login, restarts on exit).
- Ports: 1080 8080 7878 8006 8113 8989 9999.
- Manual run: `ssh-tunnel-proxy start`. Logs: `/tmp/ssh-tunnel-proxy.{out,err}.log`.
- Requires `socat` (`brew install socat`).
```

- [ ] **Step 7: Commit**

```bash
git add README.md
git commit -m "Document ssh-tunnel-proxy and mark end-to-end verification"
```

---

## Notes for the executor

- The unit tests never touch the network: `ssh`, `socat`, `ifconfig`, and `ip` are stubbed as shell functions. Only Task 10's smoke test performs real SSH/HTTP.
- Running counts in "Expected: N run, 0 failed" assume tests are added cumulatively and none removed. If you add extra assertions, adjust expectations accordingly — the invariant that matters is `0 failed`.
- `readlink -f` is used for `SELF`, matching the existing `deploy.sh` idiom; it must resolve on this machine (it does — `deploy.sh` relies on it).
- Do not enable `set -euo pipefail` at the top level of the script; it must stay inside the `BASH_SOURCE == $0` guard so sourcing for tests cannot abort the test runner.
