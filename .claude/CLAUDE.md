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