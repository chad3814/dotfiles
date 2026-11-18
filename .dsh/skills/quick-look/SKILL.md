---
name: quick-look
description: Use to show the human a file in a viewer window - when they ask to see a file, or right after writing a spec or plan markdown file
---

# quick-look

Opens a window for the human to view a file.

## When to use
- when the human requests to see a file
- after creating a plan or spec markdown file

## How to run
From anywhere:

    "$HOME/.dsh/skills/quick-look/quick-look.sh" <filename>

Run it once per file, right after the write succeeds. The command returns
immediately — do not wait on the window, and do not re-open the same file on
every subsequent edit.

## What it does
1. On macOS it opens a Quick Look window, which often shows a formatted file
2. On Linux it uses `xdg-open` to open the default viewer
