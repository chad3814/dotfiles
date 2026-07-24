# project-setup + worktree skills Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the old `repo-setup`/`worktree` skills with three script-backed skills — `project-setup`, `add-worktree`, `address-issue` — that bootstrap and operate the bare-repo + `worktrees/` layout, and move the layout description into global `~/.claude/CLAUDE.md`.

**Architecture:** Each skill is a thin `SKILL.md` (when/why + how to invoke + failure interpretation) wrapping a real, tested shell script that holds the git logic. `add-worktree.sh` is the single implementation of "create a worktree + prepare it"; `project-setup.sh` and `address-issue.sh` both call it, so worktree logic is DRY. Skills are authored in `~/dotfiles/.claude/skills/` and projected into `~/.claude/skills/` by GNU Stow.

**Tech Stack:** Bash (macOS `/bin/bash` 3.2-compatible), `git` worktrees, `gh` (GitHub CLI), GNU Stow, `shellcheck`.

## Global Constraints

- Target repo: `~/dotfiles` (git-tracked; GNU Stow → `$HOME`). Work on branch `feature/project-setup-skills` (already created).
- Scripts: begin with `#!/usr/bin/env bash` and `set -euo pipefail`; must run under macOS bash 3.2 — **no** `mapfile`, associative arrays, or `${arr[@]}` expansion of a possibly-empty array under `set -u`; keep `shellcheck`-clean.
- Layout constants (verbatim): bare dir is always `git/`; `.git` pointer contains exactly `gitdir: ./git`; every worktree lives under `worktrees/`, including the default at `worktrees/<default-branch>`; **no** per-project `.claude/CLAUDE.md` is generated; **no** `repo-config.json`.
- Prep logic (verbatim): if `scripts/worktree-setup.sh` exists and is executable in the worktree, run it (cwd = worktree, env `BRANCH`/`WORKTREE`) and stop; else auto-detect and run each present toolchain — Node/TS (`pnpm-lock.yaml`→pnpm, `yarn.lock`→yarn, `bun.lockb`→bun, else npm; then the `build` script if `package.json` defines one) and Rust (`Cargo.toml`→`cargo build`). A failing prep step is reported but never deletes the worktree.
- Skill invocation path in docs: `"$HOME/.claude/skills/<name>/<name>.sh"` (the stowed location).
- Tests live in `~/dotfiles/tests/skills/` (stow-ignored, git-tracked); hermetic — use `mktemp -d`, local-path origins, no network, and disable commit signing in scratch repos (`git -c commit.gpgsign=false`).
- **Verification per task:** run `shellcheck` on every changed `.sh` and run the task's test. Type-check and build are N/A for shell + markdown; that is the complete verification set for this project.
- **Commits require Chad's explicit approval** (standing user rule). At each commit step, ask before committing. Never push.

## File Structure

Created / modified:

```
~/dotfiles/
├── .claude/
│   ├── CLAUDE.md                              (MODIFY: append layout section)
│   └── skills/
│       ├── repo-setup/                        (DELETE)
│       ├── worktree/                          (DELETE)
│       ├── add-worktree/
│       │   ├── SKILL.md                       (CREATE)
│       │   └── add-worktree.sh                (CREATE — worktree create + prepare)
│       ├── project-setup/
│       │   ├── SKILL.md                       (CREATE)
│       │   └── project-setup.sh               (CREATE — bootstrap; calls add-worktree.sh)
│       └── address-issue/
│           ├── SKILL.md                       (CREATE)
│           └── address-issue.sh               (CREATE — gh → branch; calls add-worktree.sh)
└── tests/skills/                              (CREATE — git-tracked, stow-ignored)
    ├── helpers.sh
    ├── run.sh
    ├── test-add-worktree.sh
    ├── test-project-setup.sh
    ├── test-address-issue.sh
    └── test-claude-md.sh
```

Task order: `add-worktree` (Task 1) is the primitive the others call, so it comes first, along with the shared test `helpers.sh`. Deletion + stow (Task 5) runs last so the system is never mid-broken and one restow syncs all adds + removes.

---

### Task 1: `add-worktree` skill (primitive: create + prepare a worktree)

**Files:**
- Create: `~/dotfiles/tests/skills/helpers.sh`
- Create: `~/dotfiles/tests/skills/run.sh`
- Create: `~/dotfiles/tests/skills/test-add-worktree.sh`
- Create: `~/dotfiles/.claude/skills/add-worktree/add-worktree.sh`
- Create: `~/dotfiles/.claude/skills/add-worktree/SKILL.md`

**Interfaces:**
- Produces: `add-worktree.sh <branch>` — creates `worktrees/$(basename <branch>)`, checks out the branch (reuse local → reuse origin → new off default), copies untracked env files from a sibling worktree, runs prep; exits non-zero outside the layout / on git failure; prep failures are reported non-fatally. Called by `project-setup.sh` and `address-issue.sh` as a sibling script.
- Produces (test helpers): `make_seed <dir> [--hook] [--npm]`, `assert_eq/assert_file/assert_dir/assert_no/assert_contains`, `git_q`, `$SKILLS_DIR`.

- [ ] **Step 1: Write the test helpers**

Create `~/dotfiles/tests/skills/helpers.sh`:

```bash
# shellcheck shell=bash
# Shared helpers for skill tests. Source, don't execute.
set -euo pipefail

SKILLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.claude/skills" && pwd -P)"

fail() { echo "ASSERT FAILED: $*" >&2; exit 1; }
assert_eq()       { [ "$1" = "$2" ] || fail "expected '$2', got '$1' ($3)"; }
assert_file()     { [ -f "$1" ] || fail "missing file $1 ($2)"; }
assert_dir()      { [ -d "$1" ] || fail "missing dir $1 ($2)"; }
assert_no()       { [ ! -e "$1" ] || fail "should be absent: $1 ($2)"; }
assert_contains() { printf '%s' "$1" | grep -qF "$2" || fail "'$1' lacks '$2' ($3)"; }

# git with signing off and a throwaway identity, for scratch repos.
git_q() { git -c commit.gpgsign=false -c user.name=test -c user.email=test@example.com "$@"; }

# make_seed <dir> [--hook] [--npm]
# Creates a normal repo on branch main with an initial commit; optional extras.
make_seed() {
  local dir="$1"; shift || true
  mkdir -p "$dir"
  git_q init -q -b main "$dir"
  printf '# seed\n' > "$dir/README.md"
  git_q -C "$dir" add -A
  git_q -C "$dir" commit -qm "initial"
  while [ $# -gt 0 ]; do
    case "$1" in
      --hook)
        mkdir -p "$dir/scripts"
        printf '#!/usr/bin/env bash\ntouch "$WORKTREE/.hook-ran"\n' > "$dir/scripts/worktree-setup.sh"
        chmod +x "$dir/scripts/worktree-setup.sh"
        git_q -C "$dir" add -A; git_q -C "$dir" commit -qm "add hook";;
      --npm)
        printf '{"name":"seed","version":"1.0.0","scripts":{"build":"touch .build-ran"}}\n' > "$dir/package.json"
        git_q -C "$dir" add -A; git_q -C "$dir" commit -qm "add package.json";;
    esac
    shift
  done
}

# bare_project <project-dir> <seed-dir> — lay out project-dir as bare-repo + worktrees.
bare_project() {
  local project="$1" seed="$2"
  mkdir -p "$project"
  git clone -q --bare "$seed" "$project/git"
  git -C "$project/git" config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
  git -C "$project/git" fetch -q origin
  git -C "$project/git" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
  printf 'gitdir: ./git\n' > "$project/.git"
  mkdir -p "$project/worktrees"
}
```

- [ ] **Step 2: Write the test runner**

Create `~/dotfiles/tests/skills/run.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd -P)"
rc=0
for t in "$here"/test-*.sh; do
  echo "=== $(basename "$t") ==="
  if bash "$t"; then echo "PASS"; else echo "FAIL"; rc=1; fi
done
exit "$rc"
```

Then `chmod +x ~/dotfiles/tests/skills/run.sh`.

- [ ] **Step 3: Write the failing test for `add-worktree`**

Create `~/dotfiles/tests/skills/test-add-worktree.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
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
```

- [ ] **Step 4: Run the test to verify it fails**

Run: `bash ~/dotfiles/tests/skills/test-add-worktree.sh`
Expected: FAIL — `add-worktree.sh` does not exist yet (`bash: .../add-worktree.sh: No such file or directory`).

- [ ] **Step 5: Implement `add-worktree.sh`**

Create `~/dotfiles/.claude/skills/add-worktree/add-worktree.sh`:

```bash
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
  if [ -d "$root/worktrees/$default" ] && [ "$root/worktrees/$default" != "$path" ]; then
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
```

Then `chmod +x ~/dotfiles/.claude/skills/add-worktree/add-worktree.sh`.

- [ ] **Step 6: Run the test to verify it passes**

Run: `bash ~/dotfiles/tests/skills/test-add-worktree.sh`
Expected: PASS — prints `test-add-worktree: OK`. If a step fails, fix `add-worktree.sh` (not the test) and re-run.

- [ ] **Step 7: Write `SKILL.md`**

Create `~/dotfiles/.claude/skills/add-worktree/SKILL.md`:

```markdown
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
```

- [ ] **Step 8: Lint**

Run: `shellcheck ~/dotfiles/.claude/skills/add-worktree/add-worktree.sh ~/dotfiles/tests/skills/*.sh`
Expected: no warnings. (If `shellcheck` is missing: `brew install shellcheck`.)

- [ ] **Step 9: Commit** (ask Chad first)

```bash
git -C ~/dotfiles add .claude/skills/add-worktree tests/skills
git -C ~/dotfiles commit -m "Add add-worktree skill (script-backed) with tests"
```

---

### Task 2: `project-setup` skill (bootstrap the project directory)

**Files:**
- Create: `~/dotfiles/tests/skills/test-project-setup.sh`
- Create: `~/dotfiles/.claude/skills/project-setup/project-setup.sh`
- Create: `~/dotfiles/.claude/skills/project-setup/SKILL.md`

**Interfaces:**
- Consumes: `add-worktree.sh` (sibling script `../add-worktree/add-worktree.sh`).
- Produces: `project-setup.sh <origin-url>` — creates `<slug>/` with `git/` (bare clone), `.git` (`gitdir: ./git`), `worktrees/`, sets `origin/HEAD`, creates + prepares `worktrees/<default>` with upstream tracking; writes no CLAUDE.md and no repo-config.json.

- [ ] **Step 1: Write the failing test**

Create `~/dotfiles/tests/skills/test-project-setup.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd -P)/helpers.sh"

PS="$SKILLS_DIR/project-setup/project-setup.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# Local "origin" = a normal seed repo (git treats a local path as an origin).
seed="$tmp/myrepo"; make_seed "$seed" --hook

# Run project-setup from a parent dir; project lands at $parent/myrepo.
parent="$tmp/parent"; mkdir -p "$parent"
( cd "$parent" && bash "$PS" "$seed" >/dev/null )

proj="$parent/myrepo"
assert_dir  "$proj/git" "bare dir git/"
assert_eq   "$(git --git-dir="$proj/git" rev-parse --is-bare-repository)" "true" "git/ is bare"
assert_eq   "$(cat "$proj/.git")" "gitdir: ./git" ".git pointer content"
assert_dir  "$proj/worktrees/main" "default worktree"
assert_eq   "$(git -C "$proj/worktrees/main" rev-parse --abbrev-ref HEAD)" "main" "default branch checked out"
assert_eq   "$(git -C "$proj/worktrees/main" rev-parse --abbrev-ref 'main@{upstream}')" "origin/main" "upstream set"
assert_file "$proj/worktrees/main/.hook-ran" "prep ran in default worktree"
assert_no   "$proj/.claude" "no .claude dir written"
assert_no   "$proj/git/repo-config.json" "no repo-config.json"

echo "test-project-setup: OK"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash ~/dotfiles/tests/skills/test-project-setup.sh`
Expected: FAIL — `project-setup.sh` does not exist yet.

- [ ] **Step 3: Implement `project-setup.sh`**

Create `~/dotfiles/.claude/skills/project-setup/project-setup.sh`:

```bash
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
```

Then `chmod +x ~/dotfiles/.claude/skills/project-setup/project-setup.sh`.

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash ~/dotfiles/tests/skills/test-project-setup.sh`
Expected: PASS — `test-project-setup: OK`.

- [ ] **Step 5: Write `SKILL.md`**

Create `~/dotfiles/.claude/skills/project-setup/SKILL.md`:

```markdown
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
```

- [ ] **Step 6: Lint**

Run: `shellcheck ~/dotfiles/.claude/skills/project-setup/project-setup.sh ~/dotfiles/tests/skills/test-project-setup.sh`
Expected: no warnings.

- [ ] **Step 7: Commit** (ask Chad first)

```bash
git -C ~/dotfiles add .claude/skills/project-setup tests/skills/test-project-setup.sh
git -C ~/dotfiles commit -m "Add project-setup skill (script-backed) with test"
```

---

### Task 3: `address-issue` skill (GitHub issue → worktree)

**Files:**
- Create: `~/dotfiles/tests/skills/test-address-issue.sh`
- Create: `~/dotfiles/.claude/skills/address-issue/address-issue.sh`
- Create: `~/dotfiles/.claude/skills/address-issue/SKILL.md`

**Interfaces:**
- Consumes: `add-worktree.sh` (sibling `../add-worktree/add-worktree.sh`); `gh` on PATH.
- Produces: `address-issue.sh <issue-id>` — reads the issue via `gh`, derives `<prefix>/<id>-<title-slug>` (`fix/` for `bug` label, `feat/` for `enhancement`/`feature`, else `chore/`), and calls `add-worktree.sh`.

- [ ] **Step 1: Write the failing test (with a `gh` stub)**

Create `~/dotfiles/tests/skills/test-address-issue.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "$0")" && pwd -P)/helpers.sh"

AI="$SKILLS_DIR/address-issue/address-issue.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# Stub gh: emit "bug" for the labels query, the title otherwise.
bin="$tmp/bin"; mkdir -p "$bin"
cat > "$bin/gh" <<'STUB'
#!/usr/bin/env bash
for a in "$@"; do
  if [ "$a" = "labels" ]; then echo "bug"; exit 0; fi
done
echo "Add Dark Mode Toggle!"
STUB
chmod +x "$bin/gh"

seed="$tmp/seed"; make_seed "$seed"
proj="$tmp/proj"; bare_project "$proj" "$seed"

cd "$proj"
PATH="$bin:$PATH" bash "$AI" 21 >/dev/null

assert_dir "$proj/worktrees/21-add-dark-mode-toggle" "issue worktree created"
assert_eq  "$(git -C worktrees/21-add-dark-mode-toggle rev-parse --abbrev-ref HEAD)" \
           "fix/21-add-dark-mode-toggle" "branch prefixed fix/ from bug label"

echo "test-address-issue: OK"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash ~/dotfiles/tests/skills/test-address-issue.sh`
Expected: FAIL — `address-issue.sh` does not exist yet.

- [ ] **Step 3: Implement `address-issue.sh`**

Create `~/dotfiles/.claude/skills/address-issue/address-issue.sh`:

```bash
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
```

Then `chmod +x ~/dotfiles/.claude/skills/address-issue/address-issue.sh`.

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash ~/dotfiles/tests/skills/test-address-issue.sh`
Expected: PASS — `test-address-issue: OK`.

- [ ] **Step 5: Write `SKILL.md`**

Create `~/dotfiles/.claude/skills/address-issue/SKILL.md`:

```markdown
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
```

- [ ] **Step 6: Lint**

Run: `shellcheck ~/dotfiles/.claude/skills/address-issue/address-issue.sh ~/dotfiles/tests/skills/test-address-issue.sh`
Expected: no warnings.

- [ ] **Step 7: Commit** (ask Chad first)

```bash
git -C ~/dotfiles add .claude/skills/address-issue tests/skills/test-address-issue.sh
git -C ~/dotfiles commit -m "Add address-issue skill (script-backed) with test"
```

---

### Task 4: Global CLAUDE.md layout section

**Files:**
- Modify: `~/dotfiles/.claude/CLAUDE.md` (append a section; `~/.claude/CLAUDE.md` symlinks to it)
- Create: `~/dotfiles/tests/skills/test-claude-md.sh`

**Interfaces:**
- Produces: a "Bare-Repo + Worktrees Project Layout" section in global memory describing the layout and pointing at `add-worktree`/`address-issue`.

- [ ] **Step 1: Write the failing test**

Create `~/dotfiles/tests/skills/test-claude-md.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash ~/dotfiles/tests/skills/test-claude-md.sh`
Expected: FAIL on "heading present" (section not added yet).

- [ ] **Step 3: Append the section**

Read `~/dotfiles/.claude/CLAUDE.md`, then append the following block to the end of the file (after the last existing custom rule line, e.g. the secret-handling line). Use Edit with the current final line as the anchor; do not disturb the `@…` imports.

```markdown

# ═══════════════════════════════════════════════════
# Bare-Repo + Worktrees Project Layout
# ═══════════════════════════════════════════════════

Some projects use a **bare-repo + worktrees** layout. The project directory
(named after the repo) contains only:

- `git/` — the bare git repository (`core.bare=true`). Do not edit code here.
- `.git` — a pointer file containing `gitdir: ./git`.
- `worktrees/` — one subdirectory per checkout. `worktrees/<default-branch>/`
  (e.g. `worktrees/main/`) is the persistent default-branch worktree; every
  other subdirectory is a feature/issue worktree.

There is **no working tree at the project directory root** — all code work
happens inside a worktree under `worktrees/`.

**Detect this layout:** a project uses it when
`git --git-dir="$(git rev-parse --git-common-dir)" rev-parse --is-bare-repository`
prints `true`.

**Starting work:** to begin a branch or issue in such a project, first create a
worktree — invoke the `add-worktree` skill (with a branch name) or the
`address-issue` skill (with an issue id). Never create a working tree at the
project directory root. If asked to start work and not already inside a
worktree for it, creating the worktree is the first step.
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash ~/dotfiles/tests/skills/test-claude-md.sh`
Expected: PASS — `test-claude-md: OK`.

- [ ] **Step 5: Commit** (ask Chad first)

```bash
git -C ~/dotfiles add .claude/CLAUDE.md tests/skills/test-claude-md.sh
git -C ~/dotfiles commit -m "Document bare-repo + worktrees layout in global CLAUDE.md"
```

---

### Task 5: Delete old skills, re-stow, verify

**Files:**
- Delete: `~/dotfiles/.claude/skills/repo-setup/` (and its SKILL.md)
- Delete: `~/dotfiles/.claude/skills/worktree/` (and its SKILL.md)
- Create: (temporary) verification via `run.sh` + manual checks

- [ ] **Step 1: Remove the old skills from the source of truth**

```bash
git -C ~/dotfiles rm -r .claude/skills/repo-setup .claude/skills/worktree
```

- [ ] **Step 2: Re-stow so `~/.claude/skills` matches dotfiles**

```bash
cd ~/dotfiles && stow -R .
# Drop now-empty unfolded dirs left by the removed skills (ignore if absent):
rmdir ~/.claude/skills/repo-setup ~/.claude/skills/worktree 2>/dev/null || true
# If a dangling symlink survived restow, remove it explicitly:
[ -L ~/.claude/skills/repo-setup ] && rm ~/.claude/skills/repo-setup || true
[ -L ~/.claude/skills/worktree ] && rm ~/.claude/skills/worktree || true
```

- [ ] **Step 3: Verify the stowed state**

```bash
# New skills resolve through the symlinks:
test -f ~/.claude/skills/add-worktree/add-worktree.sh
test -f ~/.claude/skills/project-setup/project-setup.sh
test -f ~/.claude/skills/address-issue/address-issue.sh
test -f ~/.claude/skills/add-worktree/SKILL.md
# Old skills are gone:
! test -e ~/.claude/skills/repo-setup
! test -e ~/.claude/skills/worktree
echo "stow verification: OK"
```
Expected: prints `stow verification: OK` with no failed `test`.

- [ ] **Step 4: Run the full test suite**

Run: `bash ~/dotfiles/tests/skills/run.sh`
Expected: every `test-*.sh` prints `PASS`; runner exits 0.

- [ ] **Step 5: Final lint sweep**

Run: `shellcheck ~/dotfiles/.claude/skills/*/*.sh ~/dotfiles/tests/skills/*.sh`
Expected: no warnings.

- [ ] **Step 6: Commit** (ask Chad first)

```bash
git -C ~/dotfiles add -A .claude/skills tests/skills
git -C ~/dotfiles commit -m "Remove superseded repo-setup and worktree skills"
```

---

### Task 6 (optional, approval-gated): rollback-tower migration

Only perform with Chad's explicit approval — this touches `~/Projects/rollback-tower/`, not dotfiles, and is not committed anywhere.

**Files:**
- Delete: `~/Projects/rollback-tower/.claude/skills/add-worktree/`, `~/Projects/rollback-tower/.claude/skills/address-issue/` (superseded by the global skills)
- Delete/keep decision: `~/Projects/rollback-tower/.claude/CLAUDE.md` (layout now global)

- [ ] **Step 1: Confirm the commit-gate rule is not lost**

`rollback-tower/.claude/CLAUDE.md` carries a "commit only if lint/tests/build pass" gate. Chad's global rules already require lint→type-check→test→build before "done," so removing this file loses nothing material — but confirm with Chad before deleting it.

- [ ] **Step 2: Remove the redundant project-local skills and layout file (after approval)**

```bash
rm -rf ~/Projects/rollback-tower/.claude/skills/add-worktree \
       ~/Projects/rollback-tower/.claude/skills/address-issue
# Only if Chad approved dropping the layout file:
rm ~/Projects/rollback-tower/.claude/CLAUDE.md
```

- [ ] **Step 3: Smoke test the real skill (manual)**

In a real project, run `"$HOME/.claude/skills/address-issue/address-issue.sh" <a-real-open-issue-id>` and confirm a worktree is created under `worktrees/` with the derived branch. Remove the throwaway worktree afterward (`git worktree remove worktrees/<dir>`).

---

## Self-Review

**Spec coverage:**
- Delete `repo-setup` + `worktree` → Task 5. ✓
- Create `project-setup` → Task 2. ✓
- Promote `add-worktree` + `address-issue` (robust) → Tasks 1, 3 (bare-repo precondition, origin-branch reuse, safe env copy folded in). ✓
- `git/` bare dir + `gitdir: ./git`; no repo-config.json → Task 2 (asserted in test). ✓
- Worktrees under `worktrees/` incl. default → Tasks 1, 2. ✓
- No per-project `.claude/CLAUDE.md`; layout in global CLAUDE.md → Task 4 (+ Task 2 asserts none written). ✓
- Prep hybrid Node/TS + Rust, hook wins → Task 1 shared prep (tested via hook + guarded npm). ✓
- `origin/HEAD` persisted by project-setup, read by add-worktree → Task 2 step 3, Task 1 default detection. ✓
- Stow-aware author/delete/re-stow → Task 5. ✓
- rollback-tower migration (optional, gated) → Task 6. ✓

**Placeholder scan:** No TBD/TODO; every code and test step contains complete content. Template tokens (`<branch>`, `<slug>`, `<default>`, `<id>`) are runtime arguments, not plan gaps.

**Type/name consistency:** `add-worktree.sh <branch>`, `project-setup.sh <origin>`, `address-issue.sh <id>` used identically across tasks; sibling path `../add-worktree/add-worktree.sh` consistent in Tasks 2 and 3; helper names (`make_seed`, `bare_project`, `assert_*`, `git_q`, `$SKILLS_DIR`) defined in Task 1 and reused unchanged.

**Known limitation (logged, not silent):** Rust/Node prep assertions in tests are guarded on `command -v` — on a machine without `npm`/`cargo` those specific assertions are skipped; the hook-script prep path (the primary prep test) always runs.
