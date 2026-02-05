# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

promptRefactor is a Neovim plugin that lets users refactor code by sending selections (or entire files) to the Claude Code CLI (`claude -p`) and replacing the original code with the response. It requires Neovim >= 0.7.0 and an authenticated Claude Code CLI.

## Architecture

This is a standard Neovim Lua plugin with two files:

- **`plugin/llm.lua`** — Entry point. Registers the `:PromptRefactor` user command with range support (defaults to entire file). Uses a load guard (`vim.g.loaded_llm`) to prevent double-loading.
- **`lua/llm/init.lua`** — Core module. Exposes `M.setup(opts)` for configuration and `M.refactor(prompt, line1, line2)` which: captures the buffer identity at call time, extracts buffer lines, constructs a prompt with filetype-tagged code fences, spawns `claude -p` asynchronously via `vim.fn.jobstart`, pipes the prompt through stdin, strips markdown fences from the response, and replaces the original lines.

The async job flow: `jobstart` → `chansend` prompt → `chanclose stdin` → collect stdout/stderr in buffered mode → `on_exit` callback runs in `vim.schedule` to safely modify the buffer.

### Safety mechanisms

- **Buffer identity**: `bufnr` is captured at invocation time so the correct buffer is modified even if the user switches buffers during the async call. The buffer is validated (`nvim_buf_is_valid`) before writing.
- **Undo atomicity**: Buffer replacement uses `undojoin` inside `nvim_buf_call` so the entire refactor is a single undo step.
- **Concurrency guard**: `M._job_id` prevents overlapping refactor jobs; a second invocation is rejected with a warning until the first completes.

## Development

No build step, test runner, or linter is configured. To test manually, install the plugin in Neovim (e.g., symlink or use a plugin manager pointing to the local path) and run `:PromptRefactor` commands.

## Key Conventions

- The plugin namespace is `llm` (module name and global load guard), while the user-facing command is `PromptRefactor`.
- The command uses `range = "%"` so without a visual selection it operates on the entire file.
- All buffer mutations happen inside `vim.schedule` to be safe from async callback context.
- Only one refactor job can run at a time (enforced by `M._job_id`).
