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
}
run_all
finish
