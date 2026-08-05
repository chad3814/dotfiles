#!/usr/bin/env bash
# set-terminal-title.sh — Claude Code PostToolUse(Bash) hook.
#
# Sets the terminal tab title to "<repo>:<branch>" for the current working
# directory, covering both a normal git repo (.git) and the bare-repo +
# worktrees/ layout (git/). Runs after every Bash tool call, so it tracks both
# `git switch`/`git checkout` (branch changes) and `cd` into another worktree.
#
# Hook subprocesses here have no controlling tty (/dev/tty is unavailable), so
# the OSC escape can't be written to the terminal directly — instead it is
# returned to Claude Code via the `terminalSequence` output field, which Claude
# forwards to the real terminal. Prints nothing (leaves the title unchanged)
# when the cwd is not inside a git work tree.
set -uo pipefail

# The hook receives its JSON payload on stdin; prefer .cwd, fall back to $PWD.
payload="$(cat 2>/dev/null || true)"
cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null || true)"
[ -z "$cwd" ] && cwd="${PWD:-}"
{ [ -n "$cwd" ] && [ -d "$cwd" ]; } || exit 0

git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# Branch slug: basename of the branch (feature/foo -> foo); short SHA if detached.
branch="$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)"
if [ "$branch" = "HEAD" ]; then
  branch="$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null || echo detached)"
else
  branch="${branch##*/}"
fi

# Repo slug: parent of the git common dir — the project directory in the
# bare-repo + worktrees layout (git/), and the repo root for a normal repo (.git).
common="$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
[ -n "$common" ] || exit 0
repo="$(basename "$(dirname "$common")")"

# OSC 0 sets the icon + window/tab title, honored broadly across terminals.
seq="$(printf '\033]0;%s\007' "$repo:$branch")"
jq -cn --arg s "$seq" '{terminalSequence: $s}' 2>/dev/null || true
exit 0
