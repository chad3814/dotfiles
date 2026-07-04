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
