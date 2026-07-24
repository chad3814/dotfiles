#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091  # dynamic path; see tests/skills/helpers.sh
. "$(cd "$(dirname "$0")" && pwd -P)/helpers.sh"

PS="$SKILLS_DIR/project-setup/project-setup.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# Local "origin" = a normal seed repo (git treats a local path as an origin).
seed="$tmp/myrepo"; make_seed "$seed" --hook

# Run project-setup from a parent dir; project lands at $parent/myrepo.
parent="$tmp/parent"; mkdir -p "$parent"
( cd "$parent" && bash "$PS" "$seed" >/dev/null )

proj="$parent/myrepo"
assert_dir  "$proj/git" "bare dir git/"
assert_eq   "$(git --git-dir="$proj/git" rev-parse --is-bare-repository)" "true" "git/ is bare"
assert_eq   "$(cat "$proj/.git")" "gitdir: ./git" ".git pointer content"
assert_dir  "$proj/worktrees/main" "default worktree"
assert_eq   "$(git -C "$proj/worktrees/main" rev-parse --abbrev-ref HEAD)" "main" "default branch checked out"
assert_eq   "$(git -C "$proj/worktrees/main" rev-parse --abbrev-ref 'main@{upstream}')" "origin/main" "upstream set"
assert_file "$proj/worktrees/main/.hook-ran" "prep ran in default worktree"
assert_no   "$proj/.claude" "no .claude dir written"
assert_no   "$proj/git/repo-config.json" "no repo-config.json"

echo "test-project-setup: OK"
