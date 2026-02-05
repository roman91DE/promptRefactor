# promptRefactor

A Neovim plugin for refactoring code using the [Claude Code CLI](https://github.com/anthropics/claude-code).

## Requirements

- Neovim >= 0.7.0
- [Claude Code CLI](https://github.com/anthropics/claude-code) installed and authenticated

## Installation

### lazy.nvim

```lua
{ "roman91DE/promptRefactor" }
```

### packer.nvim

```lua
use "roman91DE/promptRefactor"
```

### vim-plug

```vim
Plug 'roman91DE/promptRefactor'
```

## Usage

### Refactor entire file

```vim
:PromptRefactor add error handling
```

### Refactor visual selection

1. Select lines in visual mode (`V`)
2. Run command:

```vim
:'<,'>PromptRefactor extract this into a separate function
```

The selected code will be sent to Claude along with your prompt, and the response will replace the original code.

## Examples

```vim
" Add type hints to Python functions
:PromptRefactor add type hints

" Simplify complex logic
:'<,'>PromptRefactor simplify this

" Convert to async
:'<,'>PromptRefactor convert to async/await

" Add documentation
:PromptRefactor add docstrings
```

## How it works

1. Takes your prompt and the selected code (or entire file)
2. Sends it to Claude Code CLI with instructions to return only refactored code
3. Replaces the original code with Claude's response

## License

MIT
