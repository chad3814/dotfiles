#!/usr/bin/env bash
# project-setup.sh — bootstrap a project into the bare-repo + worktrees/ layout.
set -euo pipefail

origin="${1:-}"
if [ -z "$origin" ]; then
  echo "usage: project-setup.sh <origin-url>" >&2
  exit 2
fi

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
add_worktree="$script_dir/../add-worktree/add-worktree.sh"

symref="$(git ls-remote --symref "$origin" HEAD)" || {
  echo "error: cannot reach origin: $origin" >&2; exit 1; }
default="$(printf '%s\n' "$symref" | awk '/^ref:/{sub("refs/heads/","",$2);print $2;exit}')"
if [ -z "$default" ]; then echo "error: could not determine default branch" >&2; exit 1; fi

slug="$(basename "$origin" .git)"
project="$PWD/$slug"
bare="$project/git"

if [ -e "$project" ] && [ -n "$(ls -A "$project" 2>/dev/null || true)" ]; then
  echo "error: $project exists and is not empty" >&2; exit 1
fi

mkdir -p "$project"
git clone --bare "$origin" "$bare"
git -C "$bare" config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
git -C "$bare" fetch origin
git -C "$bare" symbolic-ref refs/remotes/origin/HEAD "refs/remotes/origin/$default"
printf 'gitdir: ./git\n' > "$project/.git"
mkdir -p "$project/worktrees"

( cd "$project" && bash "$add_worktree" "$default" )

git -C "$project/worktrees/$default" branch --set-upstream-to="origin/$default" "$default" \
  || echo "warning: could not set upstream for $default" >&2

echo "project-setup: $project"
echo "  default: $default → worktrees/$default (tracking origin/$default)"
echo "  wrote git/, .git (gitdir: ./git), worktrees/; no CLAUDE.md or repo-config.json"
