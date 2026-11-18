# Information

## Chad Walker

* Human
  * The human's name is Chad.
  * personal email address is [chad@cwalker.dev](mailto:chad@cwalker.dev)
  * Chad is Staff Software Engineer and has over 30 years of programming experience
  * Chad's preferred language is currently TypeScript
  * Chad likes 2-space indents and always ends lines with semicolons when they are optional
  * Chad dislikes `any` and `unknown` types in TypeScript
  * Chad signs commits using ssh keys
  * Chad runs 1Password's ssh-agent and requires his approval on signatures every 15 minutes
  * Chad is logged into GitHub within the `gh` commandline too. His GitHub account name is `chad3814`
* Work
  * Chad is not currently employed and is looking for a new position
  * Use his personal email address for anything that needs an email; he has no work address right now
  * Previously: Staff Software Engineer at Mozilla, Inc, in the Small Business group of the New Products organization, working on [Postful](https://postful.ai) ([Mozilla-Ocho/post-host](https://github.com/Mozilla-Ocho/post-host))
* Personal
  * Chad keeps his personal project repos he's cloned in `$HOME/Projects` (same path on macOS and Linux)

# Requirements

* *NEVER* push a branch unless the human explicitly tells you to do so
* Whenever you make a code change, you are not done with the task until you have successfully verified the change through:
  * linting
  * type-checking
  * running tests
  * building
* Whenever you create a new feature, that feature needs unit tests
* *NEVER* let private keys or other secrets enter the conversation context. Do not write them to files via tools, do not `cat`/`echo` them, and do not print them in output. When a credential is needed, pipe it from its source straight to a file or env var in a single shell step (e.g. `op read`/`op run`/`op inject`, or use an on-disk key + ssh-agent) so the secret never passes through context. Avoid MCP tools that return secret values into context for keys/passwords. If a secret does end up in context, treat it as compromised and say so immediately.
* Prefer the async form of an API over its synchronous twin — `fs.promises`/`fs.*` over `fs.*Sync`, `zlib.gunzip` over `gunzipSync`, `crypto.subtle` over a blocking hash. Sync calls block the event loop, and anything sharing that loop stalls with them: in an Electron main process the window freezes and IPC stops; in a server every other request waits. Reach for `*Sync` only where nothing is waiting on the loop — build scripts, a CLI that does one thing and exits, module-level config loading at startup — and say why when you do. If you are already inside an `async` function, there is no excuse; `await` it.
* When you create or substantially rewrite a spec or plan markdown file, show it to me immediately — invoke the `quick-look` skill (with the path to the file). Do this once per file, right after the write succeeds — not on every subsequent edit, and not for ordinary docs, READMEs, or code.

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
