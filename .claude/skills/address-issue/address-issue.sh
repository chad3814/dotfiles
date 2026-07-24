#!/usr/bin/env bash
# address-issue.sh — create a worktree for a GitHub issue.
set -euo pipefail

id="${1:-}"
if [ -z "$id" ]; then echo "usage: address-issue.sh <issue-id>" >&2; exit 2; fi

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
add_worktree="$script_dir/../add-worktree/add-worktree.sh"

title="$(gh issue view "$id" --json title --jq .title)" || {
  echo "error: gh could not read issue $id (auth, or not a GitHub repo)." >&2
  echo "  A non-GitHub repo can ship its own .claude/skills/address-issue/." >&2
  exit 1
}
labels="$(gh issue view "$id" --json labels --jq '[.labels[].name]|join(",")')" || labels=""

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

branch="$prefix/$id-$slug"
echo "address-issue: #$id '$title' → $branch"
bash "$add_worktree" "$branch"
