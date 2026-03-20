# termite.nvim

Stacking float terminal manager for Neovim.

<!-- ## Demo -->
<!-- ![termite.nvim demo](https://user-images.githubusercontent.com/YOUR_USERNAME/termite.nvim/demo.gif) -->

## Features

- **Vertically stacked floating terminals** on the left or right side of the editor
- **Horizontally stacked floating terminals** on the top or bottom of the editor
- **Toggle all terminals** (show/hide) with a single key
- **Create multiple terminals** that automatically resize and reflow
- **Navigate between terminals** with next/previous keys
- **Maximize/restore** individual terminals to full height/width
- **Focus editor** while keeping terminals visible
- **Custom shell support** per terminal or global default
- **Full keymap customization**
- **Border highlighting** for active and inactive terminals (customizable)
- **Winbar** showing running process or cwd (customizable)

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
  width = 0.5,           -- Fraction of editor width for left/right positions (0.0 - 1.0)
  height = 0.5,          -- Fraction of editor height for top/bottom positions (0.0 - 1.0)
  position = "right",    -- Panel position: "left", "right", "top", or "bottom"
  border = "light",      -- Border style: "light", "heavy", "double", "double-dash", "triple-dash", "quadruple-dash"
  shell = nil,           -- Shell command (nil = default $SHELL)
  start_insert = true,   -- Enter insert mode when focusing a terminal
  winbar = true,         -- Show winbar with running process or cwd

  keymaps = {
    toggle = "<C-\\>",   -- Toggle all terminals (terminal mode)
    create = "<C-t>",    -- Create new terminal
    next = "<C-n>",      -- Focus next terminal in stack
    prev = "<C-p>",      -- Focus previous terminal in stack
    focus_editor = "<C-e>",  -- Return focus to editor window
    normal_mode = "<C-[>",   -- Exit terminal insert mode
    maximize = "<C-z>",      -- Maximize/restore focused terminal
    close = "q",             -- Close current terminal (normal mode)
  },

  wo = {                 -- Window options applied to terminal windows
    signcolumn = "yes:1",
  },

  highlights = {
    border_active = "TermiteBorder",        -- Highlight for active terminal border (string = hl group, table = direct definition)
    border_inactive = "TermiteBorderNC",    -- Highlight for inactive terminal borders (string = hl group, table = direct definition)
    border_single = "TermiteBorderSingle",  -- Highlight for single terminal border (string = hl group, table = direct definition)
    winbar = "TermiteWinbar",               -- Highlight for winbar
  },
})
```

## Highlights

termite.nvim uses three highlight groups for terminal window borders:

- `TermiteBorderSingle` - Applied when there's **only one terminal** visible
- `TermiteBorder` - Applied to the **active** (focused) terminal's outer edge when there are **2+ terminals**
- `TermiteBorderNC` - Applied to **inactive** (non-focused) terminal borders

The outer edge is:

- **Left border** when `position = "right"`
- **Right border** when `position = "left"`
- **Top border** when `position = "bottom"`
- **Bottom border** when `position = "top"`

This means only the border facing the editor is highlighted, while the separators between stacked terminals remain dimmed.

### Defaults

By default, the highlight groups link to:

- `TermiteBorderSingle` → `FloatBorder` (single terminal)
- `TermiteBorder` → `FloatBorder` (active terminal outer edge with 2+ terminals)
- `TermiteBorderNC` → `Comment` (inactive terminal outer edges)
- `TermiteWinbar` → `Normal` (winbar text)

These defaults use `default = true`, so they can be overridden by colorschemes or user configuration.

### Customizing in Colorscheme

Define the highlight groups in your colorscheme or init.lua:

```lua
-- Customize single terminal border
vim.api.nvim_set_hl(0, "TermiteBorderSingle", { fg = "#61afef", bg = "NONE" })

-- Customize active terminal border (2+ terminals)
vim.api.nvim_set_hl(0, "TermiteBorder", { fg = "#ff6b6b", bg = "NONE", bold = true })

-- Customize inactive terminal borders
vim.api.nvim_set_hl(0, "TermiteBorderNC", { fg = "#4a4a4a", bg = "NONE" })

-- Customize winbar
vim.api.nvim_set_hl(0, "TermiteWinbar", { fg = "#a0a0a0", bg = "NONE" })
```

### Customizing in Setup

You can specify highlights in two ways:

**1. Use custom highlight group names:**

```lua
require("termite").setup({
  highlights = {
    border_single = "MyCustomSingle",
    border_active = "MyCustomActive",
    border_inactive = "MyCustomInactive",
  },
})
```

**2. Define colors directly:**

```lua
require("termite").setup({
  highlights = {
    border_single = { fg = "#61afef", bg = "NONE" },
    border_active = { fg = "#00ff00", bg = "NONE" },
    border_inactive = { fg = "#ff0000", bg = "NONE" },
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
| Terminal | `<C-n>` | Focus next terminal       |
| Terminal | `<C-p>` | Focus previous terminal   |
| Terminal | `<C-e>` | Focus editor window       |
| Terminal | `<C-[>` | Exit to normal mode       |
| Terminal | `<C-z>` | Maximize/restore terminal |
| Normal   | `q`     | Close current terminal    |

Additionally, `toggle` and `create` keymaps are available in normal mode globally:

| Mode   | Key     | Action               |
| ------ | ------- | -------------------- |
| Normal | `<C-\>` | Toggle all terminals |
| Normal | `<C-t>` | Create new terminal  |

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

## Highlight API

```lua
local highlights = require("termite.highlights")

-- Highlight groups
highlights.BORDER_SINGLE         -- "TermiteBorderSingle"
highlights.BORDER_ACTIVE         -- "TermiteBorder"
highlights.BORDER_INACTIVE       -- "TermiteBorderNC"

-- Re-initialize highlight groups (useful after colorscheme change)
highlights.setup()
```

## License

MIT License - see [LICENSE](LICENSE)
