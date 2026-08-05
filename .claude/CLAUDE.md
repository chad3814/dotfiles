# SuperClaude Entry Point

This file serves as the entry point for the SuperClaude framework.
You can add your own custom instructions and configurations here.

The SuperClaude framework components will be automatically imported below.

# ═══════════════════════════════════════════════════
# SuperClaude Framework Components
# ═══════════════════════════════════════════════════

# Core Framework
@FLAGS.md
@PRINCIPLES.md
@RULES.md

# Behavioral Modes
@MODE_Brainstorming.md
@MODE_Introspection.md
@MODE_Orchestration.md
@MODE_Task_Management.md
@MODE_Token_Efficiency.md

# MCP Documentation
@MCP_Context7.md
@MCP_Magic.md
@MCP_Morphllm.md
@MCP_Playwright.md
@MCP_Sequential.md
@MCP_Serena.md
- never push git commits to the remote
never use the `any` typescript type
- *NEVER* make a commit without my explicit approval. *NEVER* push to remote without my explicit approval.
- *NEVER* let private keys or other secrets enter the conversation context. Do not write them to files via tools, do not `cat`/`echo` them, and do not print them in output. When a credential is needed, pipe it from its source straight to a file or env var in a single shell step (e.g. `op read`/`op run`/`op inject`, or use an on-disk key + ssh-agent) so the secret never passes through context. Avoid MCP tools that return secret values into context for keys/passwords. If a secret does end up in context, treat it as compromised and say so immediately.
- Prefer the async form of an API over its synchronous twin — `fs.promises`/`fs.*` over `fs.*Sync`, `zlib.gunzip` over `gunzipSync`, `crypto.subtle` over a blocking hash. Sync calls block the event loop, and anything sharing that loop stalls with them: in an Electron main process the window freezes and IPC stops; in a server every other request waits. Reach for `*Sync` only where nothing is waiting on the loop — build scripts, a CLI that does one thing and exits, module-level config loading at startup — and say why when you do. If you are already inside an `async` function, there is no excuse; `await` it.

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