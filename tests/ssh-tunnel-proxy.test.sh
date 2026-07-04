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

run_all() {
  test_sourcing_does_not_run_main
  test_unknown_subcommand_returns_2
  test_ports_hardcoded
  test_on_home_lan_true
  test_on_home_lan_false
  test_on_home_lan_no_false_positive_on_180
  test_with_lock_runs_command_and_returns_status
  test_with_lock_releases_lock
  test_with_lock_serializes
  test_primary_alive_reflects_ssh_check
  test_ensure_primary_dials_when_absent
  test_ensure_primary_skips_dial_when_present
  test_resolve_prefers_live_zeus
  test_resolve_prefers_live_home_over_lan
  test_resolve_lan_picks_zeus_and_dials
  test_resolve_offlan_picks_home
  test_connect_builds_ssh_w_command
  test_connect_requires_port
}
run_all
finish
