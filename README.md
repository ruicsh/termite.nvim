# termite.nvim

Stacking float terminal manager for Neovim.

<!-- ## Demo -->
<!-- ![termite.nvim demo](https://user-images.githubusercontent.com/YOUR_USERNAME/termite.nvim/demo.gif) -->

## Features

- **Vertically stacked floating terminals** on the left or right side of the editor
- **Toggle all terminals** (show/hide) with a single key
- **Create multiple terminals** that automatically resize and reflow
- **Navigate between terminals** with next/previous keys
- **Maximize/restore** individual terminals to full height
- **Focus editor** while keeping terminals visible
- **Custom shell support** per terminal or global default
- **Full keymap customization**

## Requirements

- Neovim >= 0.7.0

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "ruicsh/termite.nvim",
  opts = {}
}
```

## Configuration

```lua
require("termite").setup({
  width = 0.5,           -- Fraction of editor width (0.0 - 1.0)
  position = "right",    -- Panel position: "left" or "right"
  border = "│",          -- Border character on the side facing the editor
  separator = "─",       -- Horizontal separator between stacked terminals
  shell = nil,           -- Shell command (nil = default $SHELL)
  start_insert = true,   -- Enter insert mode when focusing a terminal

  keymaps = {
    toggle = "<C-\\>",   -- Toggle all terminals (terminal mode)
    create = "<C-t>",    -- Create new terminal
    next = "<C-j>",      -- Focus next terminal in stack
    prev = "<C-k>",      -- Focus previous terminal in stack
    focus_editor = "<C-h>",  -- Return focus to editor window
    normal_mode = "<C-[>",   -- Exit terminal insert mode
    maximize = "<C-z>",      -- Maximize/restore focused terminal
    close = "q",             -- Close current terminal (normal mode)
  },

  wo = {                 -- Window options applied to terminal windows
    signcolumn = "yes:1",
  },
})
```

## Keymaps

Keymaps are buffer-local to terminal windows and can be customized or disabled.

To disable a keymap, set its value to `false` or `nil`:

```lua
require("termite").setup({
  keymaps = {
    close = false,  -- Disable 'q' to close in normal mode
  },
})
```

Default keymaps:

| Mode     | Key     | Action                    |
| -------- | ------- | ------------------------- |
| Terminal | `<C-\>` | Toggle all terminals      |
| Terminal | `<C-t>` | Create new terminal       |
| Terminal | `<C-j>` | Focus next terminal       |
| Terminal | `<C-k>` | Focus previous terminal   |
| Terminal | `<C-h>` | Focus editor window       |
| Terminal | `<C-[>` | Exit to normal mode       |
| Terminal | `<C-z>` | Maximize/restore terminal |
| Normal   | `q`     | Close current terminal    |

## Commands

The `:Termite` command accepts subcommands:

```vim
:Termite              " Toggle all terminals (default)
:Termite toggle       " Toggle all terminals
:Termite create       " Create new terminal
:Termite maximize     " Maximize/restore current terminal
:Termite close        " Close current terminal
:Termite next         " Focus next terminal
:Termite prev         " Focus previous terminal
:Termite editor       " Focus editor window
```

## API

```lua
local termite = require("termite")

-- Configuration
termite.setup(opts)              -- Configure the plugin

-- Terminal management
termite.toggle()                 -- Toggle all terminals (show/hide)
termite.create()                 -- Create a new terminal
termite.close_current()          -- Close the focused terminal

-- Navigation
termite.focus_next()             -- Focus next terminal in stack
termite.focus_prev()             -- Focus previous terminal in stack
termite.focus_editor()           -- Focus editor window

-- Window state
termite.toggle_maximize()        -- Maximize/restore focused terminal
```

## License

MIT License - see [LICENSE](LICENSE)
