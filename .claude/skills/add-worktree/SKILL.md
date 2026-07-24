---
name: add-worktree
description: Use when starting work on a branch in a bare-repo + worktrees/ project. Triggers include "start work on <branch>", "new worktree for X", "create a worktree", or "/add-worktree <branch>". Not for standard single-working-tree repos.
---

# add-worktree

Create a worktree under `worktrees/` for a branch and prepare it (copy untracked env files, install, build). The git logic lives in `add-worktree.sh`; this file is guidance for invoking it.

## When to use
- A project in the bare-repo + `worktrees/` layout, and you need a checkout for a branch.
- `/add-worktree <branch>`.
Not for normal single-working-tree repos (use `git checkout -b`).

## How to run
From anywhere inside the project (any worktree, or the project directory root):

    "$HOME/.claude/skills/add-worktree/add-worktree.sh" <branch>

The worktree directory is `basename <branch>` (e.g. `feature/add-login` → `worktrees/add-login`). If no branch is given, ask the user.

## What it does
1. Verifies the bare-repo + worktrees layout (else exits non-zero).
2. Fetches origin, then reuses the branch if it exists locally or on origin, otherwise creates it off the detected default branch.
3. Prepares the worktree: copies untracked `.env*` (excluding `.env.example/.sample/.template`) from a sibling worktree; then runs `scripts/worktree-setup.sh` if present and executable, else auto-detects Node/TS (lockfile → pnpm/yarn/bun/npm install + the `build` script) and Rust (`cargo build`).

## Interpreting failures
- "not a bare-repo + worktrees project" → you are not inside such a project; do not use this skill.
- "$path already exists" / "already checked out elsewhere" → pick another branch or remove the stale worktree.
- A prep step marked FAILED leaves the worktree in place — fix the cause and re-run install/build manually.
