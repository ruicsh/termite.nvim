# AGENTS.md
# Agentic coding guidelines for termite.nvim

termite.nvim is a stacking float terminal manager for Neovim, written in Lua.

## Project Structure

```
lua/termite/
  init.lua       - Main module, public API (toggle, create, focus_next, etc.)
  config.lua     - Configuration defaults and setup
  state.lua      - Shared mutable state (terminals list, visibility flags)
  terminal.lua   - Terminal creation, lifecycle, buffer management
  layout.lua     - Window geometry: positioning, sizing, reflow
plugin/termite.lua - Autoloaded: autocmds and user commands
```

## Commands

Since this is a Neovim plugin (not a standalone application), there are no build or test commands. Use:

```bash
# Lint Lua code
luacheck lua/ plugin/

# Format Lua code (REQUIRED before committing)
stylua lua/ plugin/

# Type check with lua-language-server
lua-language-server --check lua/
```

**No tests exist.** If you add tests, place them in `spec/` using the busted framework (see `.luacheckrc`).

## Code Style

### Formatting

- **StyLua** handles all formatting via `.stylua.toml`:
  - Column width: 120
  - Indent: Tabs (width 1)
  - Quote style: AutoPreferDouble
  - Call parentheses: Always
  - Syntax: Lua52
- Never manually format code; always run `stylua`
- Line length is NOT enforced by luacheck (see `.luacheckrc` line 7)

### Module Structure

```lua
-- termite.nvim
-- Brief description of module purpose.

local config = require("termite.config")
local state = require("termite.state")

local M = {}

-- Section name {{{

M.public_function = function()
  -- implementation
end

-- Helper functions {{{

local function private_helper()
  -- implementation
end

-- }}}

-- }}}

return M

-- vim: foldmethod=marker:foldmarker={{{,}}}:foldlevel=0
```

### Naming Conventions

- **snake_case** for functions, variables, and modules
- **UPPER_CASE** for module-level constants (e.g., `DEFAULTS`, `SUBCOMMANDS`)
- Descriptive names; avoid abbreviations except well-known ones (buf, win, opts, idx)

### Imports

- Group all `require` statements at the top of the file
- Order: standard library (none here), then project modules
- Use `local M = require("termite.module")` pattern

### Comments

- **NO inline code comments** - code should be self-documenting
- File header: `-- termite.nvim` followed by brief description
- Use fold markers `-- {{{` and `-- }}}` to organize sections
- End-of-file marker: `-- vim: foldmethod=marker:foldmarker={{{,}}}:foldlevel=0`
- NOTE comments are acceptable for explaining non-obvious behavior

### Error Handling

- Always validate window/buffer handles before use:
  ```lua
  if term.win and vim.api.nvim_win_is_valid(term.win) then
    -- safe to use term.win
  end
  ```
- Use `pcall()` for operations that might fail:
  ```lua
  pcall(vim.api.nvim_win_set_cursor, win, { line_count, 0 })
  ```
- Use `vim.schedule()` for operations after async callbacks:
  ```lua
  vim.schedule(function()
    if buf and vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end)
  ```

### Neovim API Usage

- Prefer `vim.api.nvim_*` functions over deprecated `vim.fn.*` where possible
- Use `vim.tbl_deep_extend("force", default, override)` for merging options
- Create autocmds with `vim.api.nvim_create_autocmd()` and augroups
- Use `vim.keymap.set()` for keymaps with buffer-local `buffer = bufnr`
- Apply window options via `vim.wo[win][opt] = val`

### Terminal Operations

- Terminal buffers: scratch buffers (`nvim_create_buf(false, true)`)
- Windows: floating windows with `nvim_open_win()` using `relative = "editor"`
- Shell process: `vim.fn.jobstart(shell, { term = true, on_exit = ... })`
- Cleanup on exit: BufWipeout autocmd to remove from terminal stack

### Configuration

- Default values in module-level `DEFAULTS` table
- `M.setup(opts)` merges user options with `vim.tbl_deep_extend("force", ...)`
- Access via `require("termite.config").values`

### Key Principles

1. **State is centralized** in `state.lua` - terminals, visibility flags, editor window ref
2. **Layout logic is pure** in `layout.lua` - no side effects, returns config tables
3. **Terminal lifecycle** in `terminal.lua` - creates, shows, hides, closes terminals
4. **Public API** in `init.lua` - coordinates other modules, handles user actions
5. **Autoload behavior** in `plugin/termite.lua` - user commands and global autocmds

### Git

- Never commit secrets or credentials
- Run `stylua lua/ plugin/` before committing
- Follow existing commit message style if visible in history
