#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091  # dynamic path; see tests/skills/helpers.sh
. "$(cd "$(dirname "$0")" && pwd -P)/helpers.sh"

AW="$SKILLS_DIR/add-worktree/add-worktree.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# Seed with a hook and an extra origin branch to reuse.
seed="$tmp/seed"; make_seed "$seed" --hook
git_q -C "$seed" branch feature/pushed

proj="$tmp/proj"; bare_project "$proj" "$seed"
cd "$proj"

# 1) New branch off default.
bash "$AW" feature/new-thing >/dev/null
assert_dir "$proj/worktrees/new-thing" "new worktree dir"
assert_eq "$(git -C worktrees/new-thing rev-parse --abbrev-ref HEAD)" "feature/new-thing" "new branch checked out"
assert_file "$proj/worktrees/new-thing/.hook-ran" "hook prep ran"

# 2) Reuse a branch that exists only on origin.
bash "$AW" feature/pushed >/dev/null
assert_dir "$proj/worktrees/pushed" "origin-branch worktree"
assert_eq "$(git -C worktrees/pushed rev-parse --abbrev-ref HEAD)" "feature/pushed" "origin branch checked out"

# 3) Reuse an existing local branch.
git -C "$proj/git" branch fix/local-1 main
bash "$AW" fix/local-1 >/dev/null
assert_dir "$proj/worktrees/local-1" "local-branch worktree"
assert_eq "$(git -C worktrees/local-1 rev-parse --abbrev-ref HEAD)" "fix/local-1" "reused local branch checked out"

# 4) Env-file filtering (run FROM a source worktree so it is chosen as source).
bash "$AW" chore/src >/dev/null
printf 'S=1\n' > worktrees/src/.env             # untracked, not excluded -> copy
printf 'E=1\n' > worktrees/src/.env.example      # untracked, excluded    -> skip
printf 'L=1\n' > worktrees/src/.env.local        # tracked                -> skip
git_q -C worktrees/src add .env.local
git_q -C worktrees/src commit -qm "track env.local"
( cd worktrees/src && bash "$AW" feature/envtest >/dev/null )
assert_file "$proj/worktrees/envtest/.env" "untracked .env copied"
assert_no   "$proj/worktrees/envtest/.env.example" "excluded .env.example not copied"
assert_no   "$proj/worktrees/envtest/.env.local" "tracked .env.local not copied"

# 5) Precondition: fail outside a bare-repo project.
if ( cd "$tmp" && bash "$AW" whatever >/dev/null 2>&1 ); then
  fail "add-worktree should exit non-zero outside the layout"
fi

# 6) Optional Node/TS detection (only where npm is installed).
if command -v npm >/dev/null 2>&1; then
  seed2="$tmp/seed2"; make_seed "$seed2" --npm
  proj2="$tmp/proj2"; bare_project "$proj2" "$seed2"
  ( cd "$proj2" && bash "$AW" feature/build >/dev/null )
  assert_file "$proj2/worktrees/build/.build-ran" "npm build script ran"
fi

echo "test-add-worktree: OK"
