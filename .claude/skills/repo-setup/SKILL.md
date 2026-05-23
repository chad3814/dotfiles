---
name: repo-setup
description: Use when bootstrapping a new project that uses a bare-repo + sibling-worktrees layout. Triggers include "set up <repo> here", "bootstrap repo", "clone bare into this directory", or an explicit "/repo-setup" invocation. Not for cloning a normal working tree.
---

# repo-setup

Bootstrap a new project for the bare-repo + sibling-worktrees layout. Given an origin URL, clone the bare repo into a subdirectory of cwd, write the `.git` pointer file so git commands work from the project root, create a persistent default-branch worktree, write a project-root `.claude/CLAUDE.md`, and write a `repo-config.json` only when defaults need overrides.

## When to Use

- User asks to set up / bootstrap a new repo in a project that uses the bare-repo + worktrees layout.
- User invokes `/repo-setup <origin>` or makes an equivalent natural-language request.

Do NOT use this skill for normal `git clone` workflows (single working tree at the project root).

## Input

A single argument: the origin URL. Accepts:

- SSH: `git@github.com:org/repo.git`
- HTTPS: `https://github.com/org/repo.git`
- With or without the trailing `.git` suffix.

If no origin is supplied, stop and ask the user.

## Preconditions

- Cwd is the directory where the new project should live as a subdirectory (e.g. `~/Projects` for personal projects, `~/Mozilla Repos` for work). The user is responsible for cd'ing there before invoking the skill.
- The origin URL is reachable — `git ls-remote --symref "$origin" HEAD` must succeed.

## Steps

Run in order. Stop on the first failure and report it.

1. **Detect the default branch**
   - Run `git ls-remote --symref "$origin" HEAD` and parse the symref line to extract the branch name (typically `main`, sometimes `master`).
   - Bail with a clear error if this command fails (auth, network, bad URL).

2. **Derive paths**
   - `slug=$(basename "$origin" .git)`
   - `project="$PWD/$slug"`
   - `bare="$project/$slug.git"`
   - `default_wt_dir=$(basename "$default_branch")`

3. **Pre-flight**
   - Bail if `$project` exists AND is non-empty.

4. **Create the project dir**
   - `mkdir -p "$project"` (no-op if it already exists empty).

5. **Bare clone**
   - `git clone --bare "$origin" "$bare"`

6. **Configure standard fetch refspec and populate remote-tracking refs**
   - `git clone --bare` does NOT set up `refs/remotes/origin/*` by default — without this step, `origin/main` (and friends) won't exist as refs, breaking the `worktree` skill and `--set-upstream-to`.
   - `git -C "$bare" config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'`
   - `git -C "$bare" fetch origin`

7. **Write the `.git` pointer**
   - Create `$project/.git` containing the single line `gitdir: <slug>.git`.
   - Use a relative path so the project directory stays relocatable.

8. **Create the persistent default-branch worktree**
   - `git -C "$project" worktree add "$default_wt_dir" "$default_branch"`

9. **Set upstream on the default-branch worktree**
   - `git -C "$project/$default_wt_dir" branch --set-upstream-to="origin/$default_branch" "$default_branch"`
   - Now `git pull` / `git status` in the default worktree report ahead/behind correctly.

10. **Write project-root `.claude/CLAUDE.md`**
   - `mkdir -p "$project/.claude"`
   - Write `$project/.claude/CLAUDE.md` with the following content, substituting `<slug>`, `<project>`, `<origin>`, `<default_branch>`, and `<default_wt_dir>`:

     ```markdown
     # <slug>

     Project root: `<project>`. Remote: `<origin>`. Default branch: `<default_branch>`.

     ## Directory Layout

     This project uses a **bare repo + sibling worktrees** layout:

     - `<slug>.git/` — the bare git repository. Don't run commands inside it expecting to edit code.
     - `<default_wt_dir>/` — the persistent default-branch worktree.
     - Additional worktrees live as siblings of `<slug>.git/` (e.g., `<project>/<branch>/`).

     There is no working tree at the project root itself. To work on code you must be inside one of the worktree subdirectories.

     ## Workflow: Always Start in a Worktree

     Before doing any work on an issue, feature, or bugfix, create a new worktree using the `worktree` skill (`~/.claude/skills/worktree/SKILL.md`), invoking it via the `Skill` tool with the branch name as the argument.

     If the user asks you to start work and you are not already inside a worktree for that work, your first step is to invoke the `worktree` skill.
     ```

11. **Write `repo-config.json` only when needed**
    - If `$default_branch` is exactly `main`, skip this step — defaults are fine, no file is written.
    - Otherwise write `$bare/repo-config.json` containing:
      ```json
      {
        "defaultBranchWorktreeDir": "<default_wt_dir>"
      }
      ```

12. **Skip setup script**
    - Bootstrapping does NOT run any project-defined setup script. The user handles that manually inside the new default-branch worktree.

13. **Report**
    - Print the project dir path, the default branch and worktree dir name, the path of the written `CLAUDE.md`, and whether `repo-config.json` was written.

## Failure Modes

| Situation | Action |
|---|---|
| No origin URL supplied | Stop. Ask the user for the origin URL. |
| `git ls-remote --symref` fails | Stop. Surface the error (auth, network, bad URL). |
| `$project` exists and is non-empty | Stop. Suggest a different parent dir or emptying the existing dir. |
| `git clone --bare` fails | Stop. Surface git's error. Leave any partial bare repo in place for the user to inspect — do not auto-delete. |
| `git fetch origin` (step 6) fails | Stop. Surface the error. The refspec is already set; user can retry the fetch manually. |
| `git worktree add` fails | Stop. Bare repo is already in place; user can retry manually or remove and rerun. |
| `branch --set-upstream-to` fails | Report but do not bail — the worktree is usable; user can set upstream manually if needed. |
| Couldn't write `.git` pointer, `CLAUDE.md`, or `repo-config.json` | Stop. Surface the filesystem error. |

## Examples

**Personal repo, default branch `main`**

```
cwd:   ~/Projects
input: git@github.com:chad3814/cawpile.git

→ git ls-remote --symref git@github.com:chad3814/cawpile.git HEAD → main
→ slug=cawpile, project=~/Projects/cawpile, bare=~/Projects/cawpile/cawpile.git, default_wt_dir=main
→ mkdir -p ~/Projects/cawpile
→ git clone --bare git@github.com:chad3814/cawpile.git ~/Projects/cawpile/cawpile.git
→ git -C ~/Projects/cawpile/cawpile.git config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
→ git -C ~/Projects/cawpile/cawpile.git fetch origin
→ write ~/Projects/cawpile/.git → "gitdir: cawpile.git"
→ git -C ~/Projects/cawpile worktree add main main
→ git -C ~/Projects/cawpile/main branch --set-upstream-to=origin/main main
→ mkdir -p ~/Projects/cawpile/.claude
→ write ~/Projects/cawpile/.claude/CLAUDE.md (minimal template, substituted)
→ default branch is main → skip repo-config.json
→ Report: "Set up cawpile at ~/Projects/cawpile/. Default branch: main → worktree ~/Projects/cawpile/main/ tracking origin/main. Wrote ~/Projects/cawpile/.claude/CLAUDE.md. No repo-config.json written (defaults are fine)."
```

**Hypothetical work repo with default branch `master`**

```
cwd:   ~/Mozilla Repos
input: git@github.com:Mozilla-Ocho/legacy-thing.git

→ git ls-remote --symref ... HEAD → master
→ slug=legacy-thing, project=~/Mozilla Repos/legacy-thing, default_wt_dir=master
→ bare clone, write .git pointer
→ git -C "~/Mozilla Repos/legacy-thing" worktree add master master
→ write ~/Mozilla Repos/legacy-thing/.claude/CLAUDE.md (template with default_branch=master, default_wt_dir=master)
→ write ~/Mozilla Repos/legacy-thing/legacy-thing.git/repo-config.json:
  {
    "defaultBranchWorktreeDir": "master"
  }
→ Report: "Set up legacy-thing. Default branch: master → worktree master/. Wrote CLAUDE.md and repo-config.json with defaultBranchWorktreeDir=master."
```

## Common Mistakes

- **Absolute path in the `.git` pointer.** Keep it relative (`gitdir: <slug>.git`) so the project directory stays relocatable along with its bare repo.
- **Running the setup script during bootstrap.** Out of scope — the user runs setup inside the new worktree.
- **Treating an empty existing `$project` dir as a failure.** Empty is fine — proceed.
- **Writing `repo-config.json` when defaults apply.** Only write the file when there's a non-default value to record. Future schema additions (e.g. `setupScript`, `envGlobs`) follow the same rule: write only what overrides a default.
- **Auto-deleting a partial bare repo on failure.** Leave it for the user to inspect; never destructive cleanup.
- **Putting CLAUDE.md inside the default-branch worktree.** The auto-generated one belongs at `$project/.claude/CLAUDE.md` (project root, untracked), not inside a worktree where it would get committed.
- **Skipping the template substitutions.** All five placeholders (`<slug>`, `<project>`, `<origin>`, `<default_branch>`, `<default_wt_dir>`) must be replaced with actual values before writing the file.
- **Assuming `git clone --bare` sets up remote-tracking refs.** It does not. Without step 6 (refspec + fetch), there are no `refs/remotes/origin/*` refs, so the `worktree` skill can't reference `origin/main` and `--set-upstream-to=origin/<branch>` fails.
