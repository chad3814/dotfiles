#!/usr/bin/env bash
# add-worktree.sh — create a worktree under worktrees/ for a branch, then prepare it.
# Layout: bare repo in git/, worktrees under worktrees/. macOS bash 3.2 compatible.
set -euo pipefail

branch="${1:-}"
if [ -z "$branch" ]; then
  echo "usage: add-worktree.sh <branch>" >&2
  exit 2
fi

abspath_dir() { ( cd "$1" && pwd -P ); }

common_dir="$(git rev-parse --git-common-dir 2>/dev/null || true)"
if [ -z "$common_dir" ] || \
   [ "$(git --git-dir="$common_dir" rev-parse --is-bare-repository 2>/dev/null || echo false)" != "true" ]; then
  echo "error: not a bare-repo + worktrees project — run inside one" >&2
  exit 1
fi

bare="$(abspath_dir "$common_dir")"
root="$(dirname "$bare")"
dir="$(basename "$branch")"
path="$root/worktrees/$dir"

if [ -e "$path" ]; then
  echo "error: $path already exists" >&2
  exit 1
fi
if git worktree list --porcelain | grep -qxF "branch refs/heads/$branch"; then
  echo "error: branch '$branch' is already checked out elsewhere:" >&2
  git worktree list | sed 's/^/  /' >&2
  exit 1
fi

git fetch origin --prune

default="$(basename "$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true)")"
if [ -z "$default" ] || [ "$default" = "." ]; then
  default=""
  for cand in main master; do
    if git show-ref --verify --quiet "refs/remotes/origin/$cand"; then default="$cand"; break; fi
  done
fi

if git show-ref --verify --quiet "refs/heads/$branch"; then
  action="checked out existing local branch"
  git worktree add "$path" "$branch"
elif git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
  action="checked out branch from origin"
  git worktree add --track -b "$branch" "$path" "origin/$branch"
else
  if [ -z "$default" ]; then
    echo "error: no local/origin branch '$branch' and no default branch to fork from" >&2
    exit 1
  fi
  action="created new branch off origin/$default"
  git worktree add -b "$branch" "$path" "origin/$default"
fi

# ---- Prepare: copy untracked env files from a sibling worktree ----
cur="$(pwd -P)"
source_wt=""
first_wt=""
while IFS= read -r wt; do
  [ -z "$wt" ] && continue
  [ "$wt" = "$path" ] && continue
  [ "$wt" = "$bare" ] && continue
  [ -z "$first_wt" ] && first_wt="$wt"
  case "$cur/" in
    "$wt"/*) source_wt="$wt"; break;;
  esac
done < <(git worktree list --porcelain | awk '/^worktree /{print $2}')
if [ -z "$source_wt" ]; then
  if [ -n "$default" ] && [ -d "$root/worktrees/$default" ] && [ "$root/worktrees/$default" != "$path" ]; then
    source_wt="$root/worktrees/$default"
  else
    source_wt="$first_wt"
  fi
fi

copied=""
if [ -n "$source_wt" ]; then
  shopt -s nullglob dotglob
  for f in "$source_wt"/.env*; do
    b="$(basename "$f")"
    case "$b" in .env.example|.env.sample|.env.template) continue;; esac
    if git -C "$source_wt" ls-files --error-unmatch "$b" >/dev/null 2>&1; then continue; fi
    cp "$f" "$path/$b"
    copied="$copied $b"
  done
fi

# ---- Prepare: install/build (hybrid) ----
hook="$path/scripts/worktree-setup.sh"
if [ -x "$hook" ]; then
  if ( cd "$path" && BRANCH="$branch" WORKTREE="$path" "$hook" ); then
    prep="ran scripts/worktree-setup.sh"
  else
    prep="scripts/worktree-setup.sh FAILED (worktree kept)"
  fi
else
  prep=""
  if [ -f "$path/package.json" ]; then
    if   [ -f "$path/pnpm-lock.yaml" ]; then pm="pnpm"; inst="install"
    elif [ -f "$path/yarn.lock" ];      then pm="yarn"; inst=""
    elif [ -f "$path/bun.lockb" ];      then pm="bun";  inst="install"
    else pm="npm"; inst="install"; fi
    if command -v "$pm" >/dev/null 2>&1; then
      # shellcheck disable=SC2086
      if ( cd "$path" && $pm $inst ); then prep="$prep; $pm install"; else prep="$prep; $pm install FAILED"; fi
      if command -v node >/dev/null 2>&1 && \
         ( cd "$path" && node -e 'const s=require("./package.json").scripts||{};process.exit(s.build?0:1)' ) 2>/dev/null; then
        if ( cd "$path" && "$pm" run build ); then prep="$prep; $pm run build"; else prep="$prep; $pm run build FAILED"; fi
      fi
    else
      prep="$prep; $pm not installed — skipped"
    fi
  fi
  if [ -f "$path/Cargo.toml" ]; then
    if command -v cargo >/dev/null 2>&1; then
      if ( cd "$path" && cargo build ); then prep="$prep; cargo build"; else prep="$prep; cargo build FAILED"; fi
    else
      prep="$prep; cargo not installed — skipped"
    fi
  fi
  prep="${prep#; }"
  [ -z "$prep" ] && prep="no toolchain detected"
fi

echo "add-worktree: $path"
echo "  branch: $branch ($action)"
echo "  env copied:${copied:- none}"
echo "  prep: $prep"
