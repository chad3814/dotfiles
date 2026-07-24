---
name: project-setup
description: Use when bootstrapping a new project into the bare-repo + worktrees/ layout. Triggers include "set up <repo> here", "bootstrap <origin>", or "/project-setup <origin>". Not for a normal git clone.
---

# project-setup

Bootstrap a new project directory in the bare-repo + `worktrees/` layout and prepare its default worktree. The logic lives in `project-setup.sh`.

## When to use
- Set up / bootstrap a new repo into this layout.
- `/project-setup <origin>`.
Not for a normal single-working-tree clone.

## How to run
From the parent directory the project should live in (e.g. `~/Projects`, `~/Mozilla Repos`):

    "$HOME/.claude/skills/project-setup/project-setup.sh" <origin-url>

Origin may be SSH or HTTPS, with or without a trailing `.git`. If none is given, ask the user.

## What it does
Creates `<slug>/` containing `git/` (bare clone), a `.git` pointer (`gitdir: ./git`), and `worktrees/`; sets `origin/HEAD`; creates and prepares `worktrees/<default-branch>` (via add-worktree.sh) with upstream tracking. Writes no CLAUDE.md and no repo-config.json — the layout is described in global `~/.claude/CLAUDE.md`, and project-specific instructions belong in the repo's own committed CLAUDE.md.

## Interpreting failures
- Unreachable origin or a non-empty target directory → reported; nothing is deleted, so inspect and retry.
- If the default worktree's prep step failed, the project structure is still valid; re-run install/build inside `worktrees/<default>`.
