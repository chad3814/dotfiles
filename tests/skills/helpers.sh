# shellcheck shell=bash
# Shared helpers for skill tests. Source, don't execute.
set -euo pipefail

SKILLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.claude/skills" && pwd -P)"
export SKILLS_DIR

fail() { echo "ASSERT FAILED: $*" >&2; exit 1; }
assert_eq()       { [ "$1" = "$2" ] || fail "expected '$2', got '$1' ($3)"; }
assert_file()     { [ -f "$1" ] || fail "missing file $1 ($2)"; }
assert_dir()      { [ -d "$1" ] || fail "missing dir $1 ($2)"; }
assert_no()       { [ ! -e "$1" ] || fail "should be absent: $1 ($2)"; }
assert_contains() { printf '%s' "$1" | grep -qF "$2" || fail "'$1' lacks '$2' ($3)"; }

# git with signing off and a throwaway identity, for scratch repos.
git_q() { git -c commit.gpgsign=false -c user.name=test -c user.email=test@example.com "$@"; }

# make_seed <dir> [--hook] [--npm]
# Creates a normal repo on branch main with an initial commit; optional extras.
make_seed() {
  local dir="$1"; shift || true
  mkdir -p "$dir"
  git_q init -q -b main "$dir"
  printf '# seed\n' > "$dir/README.md"
  git_q -C "$dir" add -A
  git_q -C "$dir" commit -qm "initial"
  while [ $# -gt 0 ]; do
    case "$1" in
      --hook)
        mkdir -p "$dir/scripts"
        # shellcheck disable=SC2016  # single quotes intentional: $WORKTREE expands when the hook runs, not here
        printf '#!/usr/bin/env bash\ntouch "$WORKTREE/.hook-ran"\n' > "$dir/scripts/worktree-setup.sh"
        chmod +x "$dir/scripts/worktree-setup.sh"
        git_q -C "$dir" add -A; git_q -C "$dir" commit -qm "add hook";;
      --npm)
        printf '{"name":"seed","version":"1.0.0","scripts":{"build":"touch .build-ran"}}\n' > "$dir/package.json"
        git_q -C "$dir" add -A; git_q -C "$dir" commit -qm "add package.json";;
    esac
    shift
  done
}

# bare_project <project-dir> <seed-dir> — lay out project-dir as bare-repo + worktrees.
bare_project() {
  local project="$1" seed="$2"
  mkdir -p "$project"
  git clone -q --bare "$seed" "$project/git"
  git -C "$project/git" config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
  git -C "$project/git" fetch -q origin
  git -C "$project/git" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
  printf 'gitdir: ./git\n' > "$project/.git"
  mkdir -p "$project/worktrees"
}
