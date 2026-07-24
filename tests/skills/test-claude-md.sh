#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091  # dynamic path; see tests/skills/helpers.sh
. "$(cd "$(dirname "$0")" && pwd -P)/helpers.sh"

md="$(cd "$(dirname "$0")" && pwd -P)/../../.claude/CLAUDE.md"
c="$(cat "$md")"
assert_contains "$c" "Bare-Repo + Worktrees Project Layout" "heading present"
assert_contains "$c" "gitdir: ./git" "pointer documented"
assert_contains "$c" "worktrees/" "worktrees dir documented"
assert_contains "$c" "is-bare-repository" "detection rule present"
assert_contains "$c" "add-worktree" "points at add-worktree skill"
assert_contains "$c" "@FLAGS.md" "existing SuperClaude imports preserved"
echo "test-claude-md: OK"
