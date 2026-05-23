---
name: worktree
description: Use when starting work on a new branch or issue in a project laid out as a bare git repository with sibling worktrees. Triggers include "start work on", "new worktree for branch X", "create a worktree", or an explicit "/worktree" invocation. Not for projects with a standard single-working-tree layout.
---

# worktree

Create a new git worktree as a sibling of the bare repo for the given branch. Reuse the branch if it already exists locally or on origin; otherwise create a new branch off `origin/main`. Optionally copy untracked `.env` files from a sibling worktree and run a project-defined setup script. Per-project overrides are read from `<bare>/repo-config.json` when present.

## When to Use

- User asks to start work on a branch/issue in a project that uses a bare repo + sibling worktrees layout.
- User says `/worktree <branch>` or equivalent natural-language request.

Do NOT use in projects with a normal single working tree at the project root — use regular `git checkout -b` there.

## Input

A single branch name (e.g., `feature/add-login`, `fix/123-foo`, `experiment-foo`). The worktree directory name is derived as `basename "<branch>"`:

- `feature/add-login` → `add-login`
- `fix/123-foo` → `123-foo`
- `experiment-foo` → `experiment-foo`

If no branch name is supplied, stop and ask the user.

## Preconditions

Both must hold or the skill bails:

1. `git rev-parse --git-common-dir` succeeds and resolves to a path ending in `.git`.
2. `git --git-dir="$(git rev-parse --git-common-dir)" rev-parse --is-bare-repository` prints `true`.

If either check fails, stop and explain that this skill only works in a bare-repo + worktrees project layout.

## Configuration (optional)

A repo may have a `repo-config.json` file in the bare repo dir (e.g. `cawpile.git/repo-config.json`) created by the `repo-setup` skill or written by hand. All fields are optional; missing fields use defaults.

| Field | Type | Default | Effect |
|---|---|---|---|
| `defaultBranchWorktreeDir` | `string` | `"main"` | Name of the persistent default-branch worktree directory. Used to locate the env-file source and the checked-in setup script. |
| `setupScript` | `string` | _none — fall back to default lookup_ | Path to the post-create setup script, relative to the project root (or absolute). When set, replaces the default lookup entirely. |
| `envGlobs` | `string[]` | `[".env*"]` excluding `.env.example`, `.env.sample`, `.env.template` | Glob patterns for files to copy from the source worktree (untracked files only). Patterns may include subdirectories (e.g. `apps/web/.env.local`) for monorepos. When set, replaces the default patterns entirely. |

## Steps

Run in order. Stop on the first failure and report it.

1. **Derive paths**
   - `bare=$(realpath "$(git rev-parse --git-common-dir)")` — absolute bare-repo path.
   - `root=$(dirname "$bare")` — project root.
   - `dir=$(basename "$branch")` — worktree directory name.
   - `path="$root/$dir"` — full worktree path.

2. **Load repo-config**
   - If `$bare/repo-config.json` exists, parse it as JSON.
     - On parse error, bail with a clear message — a malformed config is a misconfiguration the user should fix, not something to silently fall through.
   - If it doesn't exist, use defaults throughout.
   - Bind: `default_wt = config.defaultBranchWorktreeDir ?? "main"`, `setup_script = config.setupScript` (may be empty), `env_globs = config.envGlobs` (may be empty).

3. **Pre-flight**
   - Bail if `$path` already exists on disk.
   - Bail if `git worktree list --porcelain` already lists `$branch` (a branch can only be checked out in one worktree).

4. **Fetch**
   - `git fetch origin --prune`

5. **Create or check out**
   - If `git show-ref --verify --quiet "refs/heads/$branch"` → branch exists locally:
     `git worktree add "$path" "$branch"`
   - Else if `git show-ref --verify --quiet "refs/remotes/origin/$branch"` → branch exists on origin only:
     `git worktree add --track -b "$branch" "$path" "origin/$branch"`
   - Else → new branch off main:
     `git worktree add -b "$branch" "$path" "origin/main"`

6. **Copy untracked env files from a sibling worktree**
   - Pick a source worktree, in this order of preference:
     1. The worktree whose path is a parent of the current working directory (skill was run from inside a worktree).
     2. `$root/$default_wt` if it exists and `git worktree list --porcelain` registers it.
     3. The first sibling worktree from `git worktree list --porcelain` whose path is neither `$path` nor `$bare`.
   - If no source worktree exists yet (the new one is the first), skip this step.
   - Determine which patterns to use:
     - If `env_globs` is set (non-empty list), use those patterns exactly as given.
     - Otherwise default to all files matching `.env*` in the source worktree root, excluding `.env.example`, `.env.sample`, `.env.template`.
   - For each pattern, expand it inside the source worktree, then filter the matches to files NOT tracked by git (`git -C "$source" ls-files --error-unmatch "<file>"` exits non-zero).
   - Copy each matching file into `$path` preserving its relative path. Use `mkdir -p` on the destination's parent dir for patterns with subdirectories.

7. **Run optional setup script**
   - Determine the script path:
     - If `setup_script` is set in repo-config, use it. If relative, resolve against `$root`. If absolute, use as-is.
     - Otherwise look up in this order: (a) `$root/$default_wt/scripts/worktree-setup.sh` — the checked-in version; (b) `$bare/worktree-setup.sh` — uncommitted fallback.
   - If a script path was resolved AND the file is executable, run it from cwd `$path` with env vars `BRANCH=$branch` and `WORKTREE=$path`. Stream its output.
   - If a script file exists but isn't executable, report its path and a `chmod +x` suggestion; do not run.
   - If no script is found, skip silently.
   - If the script exits non-zero, surface the failure but DO NOT delete the worktree — the user can fix and re-run.

8. **Report**
   - Print: the new worktree path; the branch action (new off `origin/main` / checked out local / checked out from origin); names of env files copied; setup-script outcome.

## Failure Modes

| Situation | Action |
|---|---|
| Not a bare-repo + worktrees project | Stop. Explain the required layout. |
| No branch argument | Stop. Ask user for the branch name. |
| `repo-config.json` is malformed JSON | Stop. Surface the parse error and the file path. |
| `$path` already exists | Stop. Suggest a different branch name or removing the existing directory. |
| Branch already in another worktree | Stop. Surface the existing path from `git worktree list`. |
| `git fetch` fails | Stop. Surface the error (commonly network or auth). |
| Setup script exits non-zero | Report failure. Leave the worktree in place. |

## Examples

**New branch off main, no config file**

```
input: feature/add-login
bare = /Users/chad/Projects/cawpile/cawpile.git
root = /Users/chad/Projects/cawpile
path = /Users/chad/Projects/cawpile/add-login
No repo-config.json → default_wt=main, no setup_script override, no env_globs override.
Neither refs/heads/feature/add-login nor refs/remotes/origin/feature/add-login exists.
→ git worktree add -b feature/add-login /Users/chad/Projects/cawpile/add-login origin/main
→ Source worktree: /Users/chad/Projects/cawpile/main
→ Copy .env, .env.local (untracked) from main
→ Look for /Users/chad/Projects/cawpile/main/scripts/worktree-setup.sh → run it
```

**Resuming an abandoned worktree (branch exists locally)**

```
input: feature/add-login
refs/heads/feature/add-login exists.
→ git worktree add /Users/chad/Projects/cawpile/add-login feature/add-login
```

**Picking up a branch pushed from another machine**

```
input: fix/issue-99
Only refs/remotes/origin/fix/issue-99 exists.
→ git worktree add --track -b fix/issue-99 /Users/chad/Projects/cawpile/issue-99 origin/fix/issue-99
```

**Monorepo with custom env paths and a master default branch**

```
repo-config.json:
{
  "defaultBranchWorktreeDir": "master",
  "envGlobs": ["apps/web/.env.local", "apps/api/.env"],
  "setupScript": "scripts/setup-worktree.sh"
}

input: feature/new-api
→ default_wt = master, source worktree falls back to $root/master if cwd isn't inside another worktree
→ Copy apps/web/.env.local and apps/api/.env (untracked) from master into the new worktree, creating apps/web/ and apps/api/ dirs as needed
→ Run $root/scripts/setup-worktree.sh from the new worktree
```

## Common Mistakes

- **Skipping `realpath` on the bare-repo path.** `git rev-parse --git-common-dir` may return a relative path; always resolve before deriving `$root`.
- **Treating `$PWD` as the project root.** When invoked from inside a worktree, `$PWD` is the worktree. Project root comes from the bare-repo path.
- **Silently ignoring a malformed `repo-config.json`.** Bail instead — the user should fix it, not have the skill paper over it.
- **Combining default env globs with `envGlobs` overrides.** When `envGlobs` is set, it REPLACES the defaults, it does not extend them. Same for `setupScript`.
- **Copying tracked files.** Filter env-file copying to files not tracked by git (`git ls-files --error-unmatch` exits non-zero) regardless of whether defaults or `envGlobs` are in use.
- **Running the setup script from the wrong cwd.** It must run with cwd set to the new worktree path, not the project root.
- **Deleting the worktree on setup-script failure.** The worktree itself is valid; only the optional post-create hook had trouble. Leave it so the user can fix and rerun.
