# Project-Setup + Worktree Skills — Design

Date: 2026-07-24
Status: Approved (design); pending implementation plan

## Motivation

Chad's bare-repo + sibling-worktrees layout has diverged from the skills that
were supposed to produce it. The existing global `repo-setup` skill writes a
`<slug>.git/` bare dir, a `gitdir: <slug>.git` pointer, a per-project
`.claude/CLAUDE.md`, and a `repo-config.json`. The layout he actually prefers
(as seen in `~/Projects/rollback-tower/`) is simpler: a `git/` bare dir, a
`gitdir: ./git` pointer, no `repo-config.json`, and worktrees grouped under a
subdirectory. This spec reconciles the two into one canonical, general,
version-controlled set of skills.

## Decisions

1. **Delete** the global `repo-setup` skill.
2. **Delete** the global `worktree` skill.
3. **Create `project-setup`** — supersedes `repo-setup`; named for setting up
   the whole *project directory*, not just cloning a repo.
4. **Promote `add-worktree` and `address-issue`** from project-local
   (`rollback-tower/.claude/skills/`) into the version-controlled global skills
   dir, folding in the robustness of the deleted `worktree` skill.
5. Bare repo dir is always **`git/`**; pointer is always **`gitdir: ./git`**.
   No `<slug>`-based naming.
6. **No `repo-config.json`.** Everything it configured becomes runtime
   detection + fixed conventions.
7. **All worktrees live under `worktrees/`**, including the persistent
   default-branch worktree (`worktrees/main/`).
8. Terminology: the root is the **"project directory."**
9. **No generated per-project `.claude/CLAUDE.md`.** The generic layout lives in
   global `~/.claude/CLAUDE.md`; project-specific instructions live in the
   repo's own committed `CLAUDE.md`.
10. `project-setup` **prepares the default worktree** (install + build), not
    just the git structure.
11. Prep logic is **hybrid**: run a repo hook script if present, else
    auto-detect the toolchain (Node/TS **and** Rust) and install + build.
12. **Script-backed skills** (refinement, decided post-approval). Each skill is
    a thin `SKILL.md` (when/why + how to invoke + failure interpretation)
    wrapping a tested shell script that holds the git logic. The exact script
    the skill runs is what the tests exercise — DRY and deterministic.
13. **`project-setup` composes `add-worktree`** (refinement). Rather than
    duplicating a shared prep procedure, `project-setup` establishes the git
    structure and then invokes `add-worktree` to create *and* prepare the
    default worktree, then sets upstream. Worktree logic lives in one place
    (`add-worktree.sh`).

## Environment facts (verified 2026-07-24)

- **Stow-managed.** `~/dotfiles/` is the canonical, version-controlled source.
  `cd ~/dotfiles && stow .` projects symlinks into `$HOME`. `~/.claude/CLAUDE.md`
  is a symlink to `~/dotfiles/.claude/CLAUDE.md`; skill files under
  `~/.claude/skills/<name>/` are symlinks into `~/dotfiles/.claude/skills/<name>/`.
- `~/.claude/skills/` is an **unfolded** stow directory: it also holds
  local-only, non-stowed entries (`file-receipt/` real dir; `work-next@`
  symlink to a Projects path). New version-controlled skills go in dotfiles and
  are stowed.
- `.stow-local-ignore` excludes `docs`, `tests`, `deploy.sh`, `.git`, `LICENSE`,
  `README.md` — so `~/dotfiles/docs/` is git-tracked but never symlinked home.
  This spec lives there.
- **CLAUDE.md discovery** (per Claude Code docs): user `~/.claude/CLAUDE.md`
  loads unconditionally; project memory is discovered by walking *up the
  filesystem tree* from cwd, loading `./CLAUDE.md` or `./.claude/CLAUDE.md` at
  each level and concatenating (cwd wins on conflict). The walk-up is
  filesystem-based, not git-aware, so a worktree's `.git` *file* does not
  interfere. Subdirectory CLAUDE.md files below cwd are lazy-loaded on read.
  Consequence: a repo's committed CLAUDE.md loads automatically when cwd is
  inside its worktree; the bare `git/` dir is a sibling of `worktrees/`, never
  an ancestor of a worktree, so it never pollutes context. No parent
  `.claude/CLAUDE.md` is needed.

## Directory layout

```
<slug>/                    ← project directory
├── .git                   → gitdir: ./git
├── git/                   ← bare repo (core.bare=true)
└── worktrees/
    ├── <default-branch>/  ← persistent default worktree (e.g. main/)
    └── <feature>/ …       ← one dir per additional worktree
```

## Global `~/.claude/CLAUDE.md` addition

Append a self-contained section (exact prose finalized during authoring):

- Some projects use a **bare-repo + worktrees** layout. The project directory
  contains only `git/` (the bare repo), a `.git` pointer file
  (`gitdir: ./git`), and `worktrees/`. There is **no working tree at the project
  directory root** — code work happens inside a worktree under `worktrees/`.
- `worktrees/<default-branch>/` is the persistent default-branch worktree; each
  other subdirectory is a feature/issue worktree.
- **Detection:** a project uses this layout when
  `git --git-dir="$(git rev-parse --git-common-dir)" rev-parse --is-bare-repository`
  prints `true`.
- **To start work** on a branch or issue, invoke the `add-worktree` skill
  (branch name) or `address-issue` skill (issue id). Never create a working
  tree at the project directory root.

Before editing, confirm `~/.claude/CLAUDE.md` resolves to the dotfiles file
(it does today) so the edit is version-controlled.

## Skill: `project-setup`

**Purpose:** bootstrap a new project directory in this layout and make the
default worktree immediately workable.

**Input:** a single origin URL (SSH or HTTPS, trailing `.git` optional). If
missing, stop and ask.

**Preconditions:** cwd is the parent dir where `<slug>/` should be created; the
origin is reachable (`git ls-remote --symref "$origin" HEAD` succeeds).

**Steps (stop on first failure; never auto-delete a partial clone):**

1. Detect default branch from `git ls-remote --symref "$origin" HEAD`.
2. Derive `slug=basename origin .git`, `project=$PWD/$slug`, `bare=$project/git`.
3. Bail if `$project` exists and is non-empty.
4. `mkdir -p "$project"`.
5. `git clone --bare "$origin" "$bare"`.
6. `git -C "$bare" config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'`
   then `git -C "$bare" fetch origin` (populates `refs/remotes/origin/*`).
7. Persist the default: `git -C "$bare" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/<default>`
   (so `add-worktree` can detect it later).
8. Write `$project/.git` containing exactly `gitdir: ./git`.
9. `mkdir -p "$project/worktrees"`.
10. Create and prepare the default worktree by invoking `add-worktree` with
    `<default>` from cwd `$project`: it creates `worktrees/<default>`, skips
    env-copy (first worktree), and runs install/build.
11. Set upstream: `git -C "$project/worktrees/<default>" branch --set-upstream-to=origin/<default> <default>`.
12. Report: project path, default branch/worktree, prep outcome. Writes **no**
    `CLAUDE.md` and **no** `repo-config.json`.

**Failure modes:** no origin → ask; `ls-remote` fails → surface (auth/net/URL);
`$project` non-empty → stop; clone/fetch/worktree failures → surface and leave
artifacts for inspection; set-upstream failure → report but do not bail.

## Skill: `add-worktree`

**Purpose:** create a new worktree under `worktrees/` for a branch and prepare
it. Robust successor to the deleted `worktree` skill.

**Input:** a branch name (e.g. `feature/add-login`, `fix/123-foo`). Worktree dir
= `basename(branch)`. If missing, stop and ask.

**Precondition:** bare-repo + worktrees layout — bail unless
`git --git-dir="$(git rev-parse --git-common-dir)" rev-parse --is-bare-repository`
is `true`. (The old name-based `.git`-suffix check is dropped; the bare dir is
now `git/`.)

**Steps (stop on first failure):**

1. `bare=$(realpath "$(git rev-parse --git-common-dir)")`; `root=$(dirname "$bare")`;
   `dir=$(basename "$branch")`; `path="$root/worktrees/$dir"`.
2. Bail if `$path` exists, or if `git worktree list --porcelain` already lists
   `$branch`.
3. `git fetch origin --prune`.
4. Determine default branch:
   `default=$(basename "$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)")`,
   fallback `main`, then `master`.
5. Create/checkout:
   - local branch exists → `git worktree add "$path" "$branch"`;
   - origin-only branch → `git worktree add --track -b "$branch" "$path" "origin/$branch"`;
   - neither → `git worktree add -b "$branch" "$path" "origin/$default"`.
6. **Prepare the worktree** using the shared procedure below.
7. Report: worktree path, branch action, env files copied, prep outcome.

**Failure modes:** not a bare-repo layout → stop and explain; no branch → ask;
`$path` exists / branch already checked out → stop with the conflicting path;
fetch failure → surface.

## Skill: `address-issue`

**Purpose:** create a worktree for a tracker issue.

**Input:** an issue id (e.g. `21`). If missing, stop and ask.

**Steps:** fetch the issue via `gh`, derive a prefixed branch name
(`feat/`/`fix/`/`chore/` + id + short slug), then invoke `add-worktree` with
that branch name.

**Default tracker:** GitHub via `gh`. **Override:** a repo using a different
tracker commits its own `.claude/skills/address-issue/` inside the repo, which
wins when cwd is inside that worktree (project skills override user skills).

## Shared procedure: "prepare a worktree"

Implemented once inside `add-worktree.sh` and reused by `project-setup` through
composition (it invokes `add-worktree`), so there is a single implementation.

1. **Copy env files.** Skip if this is the first worktree (no source). Pick a
   source worktree in this order: the worktree containing cwd (if invoked from
   inside one); else `worktrees/<default>`; else the first other worktree from
   `git worktree list --porcelain`. Copy untracked files matching `.env*`
   (excluding `.env.example`, `.env.sample`, `.env.template`) — untracked only
   (`git ls-files --error-unmatch <f>` exits non-zero) — into the new worktree,
   preserving relative paths.
2. **Install + build (hybrid).**
   - If `scripts/worktree-setup.sh` exists and is executable in the new
     worktree, run it from cwd = the worktree with env `BRANCH` and `WORKTREE`,
     stream output, and do nothing further (the repo owns its logic).
   - Otherwise auto-detect and run each toolchain present:
     - **Node/TS:** pick the package manager from the lockfile
       (`pnpm-lock.yaml`→pnpm, `yarn.lock`→yarn, `bun.lockb`→bun,
       `package-lock.json`→npm; default npm if only `package.json`), run its
       install, then run the `build` script if `package.json` defines one.
     - **Rust:** if `Cargo.toml` is present, run `cargo build`.
3. **Non-fatal.** A failing prep step is reported but never deletes the
   worktree — the user fixes and re-runs.

## Deletion & migration

- Remove `~/dotfiles/.claude/skills/repo-setup/` and
  `~/dotfiles/.claude/skills/worktree/`, then re-stow so the corresponding
  `~/.claude/skills/*` symlinks are removed (clean up any now-empty unfolded
  real dirs left behind).
- **Optional, only with explicit approval:** delete the now-redundant
  `add-worktree/`, `address-issue/`, and layout `.claude/CLAUDE.md` from
  `~/Projects/rollback-tower/.claude/`. Note: rollback-tower's CLAUDE.md also
  carries a "commit only if lint/tests/build pass" gate; Chad's global rules
  already require lint→type-check→test→build before "done," so it is largely
  redundant, but confirm before removing.

## Verification

- After stowing, `~/.claude/skills/` lists `project-setup`, `add-worktree`,
  `address-issue` and no longer resolves `repo-setup`/`worktree`.
- `/context` inside a bare-repo worktree shows global `~/.claude/CLAUDE.md`
  plus the repo's committed CLAUDE.md loaded.
- End-to-end smoke test: run `project-setup` against a small test repo in a
  temp parent dir; confirm the `git/` + `.git` + `worktrees/<default>/` layout,
  upstream tracking, and prep; then run `add-worktree feature/x` and confirm the
  new worktree plus env-copy + install/build. Clean up the temp dir.

## Non-goals

- Configurable per-repo overrides beyond the `scripts/worktree-setup.sh` hook
  (that is what dropping `repo-config.json` buys — monorepo-custom env paths
  lose their config home; acceptable).
- Any working tree at the project directory root.
- Toolchains beyond Node/TS and Rust in the auto-detect path (a repo needing
  others uses the hook script).
```
