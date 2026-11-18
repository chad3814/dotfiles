#!/usr/bin/env bash
# address-issue.sh — create a worktree for a GitHub issue.
set -euo pipefail

id="${1:-}"
if [ -z "$id" ]; then echo "usage: address-issue.sh <issue-id>" >&2; exit 2; fi

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
add_worktree="$script_dir/../add-worktree/add-worktree.sh"

meta="$(gh issue view "$id" --json title,labels --jq '.title, ([.labels[].name]|join(","))')" || {
  echo "error: gh could not read issue $id (auth, or not a GitHub repo)." >&2
  echo "  A non-GitHub repo can ship its own .dsh/skills/address-issue/." >&2
  exit 1
}
title="$(printf '%s\n' "$meta" | sed -n '1p')"
labels="$(printf '%s\n' "$meta" | sed -n '2p')"

prefix="chore"
case ",$labels," in
  *,bug,*) prefix="fix";;
  *,enhancement,*|*,feature,*) prefix="feat";;
esac

slug="$(printf '%s' "$title" \
  | tr '[:upper:]' '[:lower:]' \
  | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' \
  | cut -c1-50 \
  | sed -E 's/-+$//')"
if [ -z "$slug" ]; then
  echo "error: issue #$id has no title-able text to derive a branch name from." >&2
  exit 1
fi

branch="$prefix/$id-$slug"
echo "address-issue: #$id '$title' → $branch"
bash "$add_worktree" "$branch"
