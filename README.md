# termite.nvim

Stacking float terminal manager for Neovim.

<img src="assets/screenshot.gif" />

## Features

- **Two layout modes:**
  - **Stack layout** (default): Vertically or horizontally stacked terminals with border highlighting
  - **Tmux layout**: Tmux-style splits with cardinal navigation (up/down/left/right)
- **Toggle all terminals** (show/hide) with a single key
- **Create multiple terminals** that automatically resize and reflow
- **Navigate between terminals** (next/previous in stack, or cardinal directions in tmux)
- **Maximize/restore** individual terminals to full height/width
- **Focus editor** while keeping terminals visible, and focus back with a single key
- **Custom shell support** per terminal or global default
- **Full keymap customization**
- **Border highlighting** for active and inactive terminals (customizable, stack layout only)
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
  layout = "stack",      -- Layout mode: "stack" (default) or "tmux"
  width = 0.5,           -- Fraction of editor width for left/right positions (0.0 - 1.0)
  height = 0.5,          -- Fraction of editor height for top/bottom positions (0.0 - 1.0)
  position = "right",    -- Panel position: "left", "right", "top", or "bottom"
  border = "light",      -- Border style: "light", "heavy", "double", "double-dash", "triple-dash", "quadruple-dash"
  shell = nil,           -- Shell command (nil = default $SHELL)
  start_insert = true,   -- Enter insert mode when focusing a terminal
  winbar = true,         -- Show winbar with running process or cwd

  keymaps = {
    toggle = "<C-\>",   -- Toggle all terminals (terminal mode)
    create = "<C-t>",    -- Create new terminal
    next = "<C-n>",      -- Focus next terminal in stack (stack layout)
    prev = "<C-p>",      -- Focus previous terminal in stack (stack layout)
    focus_editor = "<C-e>",  -- Return focus to editor window
    normal_mode = "<C-[>",   -- Exit terminal insert mode
    maximize = "<C-z>",      -- Maximize/restore focused terminal
    close = "q",             -- Close current terminal (normal mode)
    -- Tmux layout only:
    split_up = "<S-Up>",     -- Split pane upward
    split_down = "<S-Down>", -- Split pane downward
    split_left = "<S-Left>", -- Split pane leftward
    split_right = "<S-Right>", -- Split pane rightward
    focus_up = "<C-Up>",     -- Focus pane above
    focus_down = "<C-Down>", -- Focus pane below
    focus_left = "<C-Left>", -- Focus pane to the left
    focus_right = "<C-Right>", -- Focus pane to the right
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

## Layouts

termite.nvim supports two layout modes:

### Stack Layout (Default)

Terminals are stacked vertically or horizontally based on the `position` setting:

- `position = "left"` or `"right"`: Vertically stacked terminals
- `position = "top"` or `"bottom"`: Horizontally stacked terminals

Features:

- **Border highlighting**: Different borders for single, active, and inactive terminals
- **Navigation**: Use `next`/`prev` keymaps to cycle through terminals in order
- **Auto-reflow**: Terminals automatically resize when created or closed

### Tmux Layout

Tmux-style pane splits with cardinal navigation:

```lua
require("termite").setup({
  layout = "tmux",
  position = "right",  -- Panel position for the root pane
  width = 0.5,
  height = 0.5,
})
```

Features:

- **No borders**: Clean look with no visible borders between panes
- **Split in any direction**: Create panes with `split_up`, `split_down`, `split_left`, `split_right`
- **Spatial navigation**: Focus panes with `focus_up`, `focus_down`, `focus_left`, `focus_right`
- **Pane tree structure**: Panes form a binary tree that automatically reflows

Key differences from stack layout:

| Feature    | Stack Layout               | Tmux Layout               |
| ---------- | -------------------------- | ------------------------- |
| Borders    | Yes (configurable)         | No                        |
| Navigation | Sequential (`next`/`prev`) | Spatial (arrow keys)      |
| Splitting  | Automatic stacking         | Manual directional splits |
| Layout     | Single stack               | Binary tree of splits     |

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

| Mode     | Key         | Action                                   | Layout |
| -------- | ----------- | ---------------------------------------- | ------ |
| Terminal | `<C-\>`     | Toggle all terminals (smart: focus back) | Both   |
| Terminal | `<C-t>`     | Create new terminal                      | Both   |
| Terminal | `<C-n>`     | Focus next terminal                      | Stack  |
| Terminal | `<C-p>`     | Focus previous terminal                  | Stack  |
| Terminal | `<C-e>`     | Focus editor window                      | Both   |
| Terminal | `<C-[>`     | Exit to normal mode                      | Both   |
| Terminal | `<C-z>`     | Maximize/restore terminal                | Both   |
| Normal   | `q`         | Close current terminal                   | Both   |
| Terminal | `<S-Up>`    | Split pane upward                        | Tmux   |
| Terminal | `<S-Down>`  | Split pane downward                      | Tmux   |
| Terminal | `<S-Left>`  | Split pane leftward                      | Tmux   |
| Terminal | `<S-Right`  | Split pane rightward                     | Tmux   |
| Terminal | `<C-Up>`    | Focus pane above                         | Tmux   |
| Terminal | `<C-Down>`  | Focus pane below                         | Tmux   |
| Terminal | `<C-Left>`  | Focus pane to the left                   | Tmux   |
| Terminal | `<C-Right>` | Focus pane to the right                  | Tmux   |

Additionally, `toggle` and `create` keymaps are available in normal mode globally:

| Mode   | Key     | Action                                   |
| ------ | ------- | ---------------------------------------- |
| Normal | `<C-\>` | Toggle all terminals (smart: focus back) |
| Normal | `<C-t>` | Create new terminal                      |

**Smart toggle behavior:** When terminals are visible and you press `<C-\>` while focus is on the editor, it focuses the terminals instead of hiding them. This lets you switch between editor and terminals with the same key.

## Commands

The `:Termite` command accepts subcommands:

```vim
:Termite              " Toggle all terminals (default)
:Termite toggle       " Toggle all terminals (smart: focuses terminals if in editor)
:Termite create       " Create new terminal
:Termite maximize     " Maximize/restore current terminal
:Termite close        " Close current terminal
:Termite next         " Focus next terminal
:Termite prev         " Focus previous terminal
:Termite editor       " Focus editor window
:Termite terminals    " Focus the terminal stack
```

## API

```lua
local termite = require("termite")

-- Configuration
termite.setup(opts)              -- Configure the plugin

-- Terminal management
termite.toggle()                 -- Toggle all terminals (show/hide)
-- Smart toggle: if terminals visible and focus is on editor, focuses terminals
-- otherwise toggles visibility
termite.create()                 -- Create a new terminal
termite.close_current()          -- Close the focused terminal

-- Navigation (stack layout)
termite.focus_next()             -- Focus next terminal in stack
termite.focus_prev()             -- Focus previous terminal in stack
termite.focus_editor()           -- Focus editor window
termite.focus_terminals()        -- Focus the terminal stack (last terminal)

-- Tmux layout splits
termite.split_up()               -- Split pane upward (tmux layout)
termite.split_down()             -- Split pane downward (tmux layout)
termite.split_left()             -- Split pane leftward (tmux layout)
termite.split_right()            -- Split pane rightward (tmux layout)

-- Tmux layout navigation
termite.focus_up()               -- Focus pane above (tmux layout)
termite.focus_down()             -- Focus pane below (tmux layout)
termite.focus_left()             -- Focus pane to the left (tmux layout)
termite.focus_right()            -- Focus pane to the right (tmux layout)

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

## Testing

Tests use [plenary.nvim](https://github.com/nvim-lua/plenary.nvim).

Run tests:

```bash
make test                    # Run all tests
make test-file FILE=spec/config_spec.lua  # Run specific test file
```

## License

MIT License - see [LICENSE](LICENSE)
