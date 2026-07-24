---
name: address-issue
description: Use when starting work on a tracker issue in a bare-repo + worktrees/ project. Triggers include "work on issue 21", "address issue #21", or "/address-issue 21". Default tracker is GitHub via gh; a repo may override with its own committed .claude/skills/address-issue.
---

# address-issue

Create a worktree for a GitHub issue: read the issue, derive a branch name, and hand off to add-worktree. Logic lives in `address-issue.sh`.

## How to run
From inside the project:

    "$HOME/.claude/skills/address-issue/address-issue.sh" <issue-id>

If no id is given, ask the user.

## What it does
Reads the issue via `gh`, derives a branch name (`fix/` for a `bug` label, `feat/` for `enhancement`/`feature`, else `chore/`, plus `<id>-<title-slug>`), and runs add-worktree.sh with it.

## Other trackers
The default assumes GitHub via `gh`. A repo using a different tracker commits its own `.claude/skills/address-issue/` in the repo; when cwd is inside that worktree, the project skill overrides this user-level one. If `gh` fails here on a non-GitHub repo, that override is the fix.
