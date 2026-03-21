# AGENTS.md
# Agentic coding guidelines for termite.nvim

termite.nvim is a stacking float terminal manager for Neovim, written in Lua.

## Project Structure

```
lua/termite/
  init.lua         - Main module, public API (toggle, create, focus_next, etc.)
  config.lua       - Configuration defaults and setup
  state.lua        - Shared mutable state (terminals list, visibility flags)
  terminal.lua     - Terminal creation, lifecycle, buffer management
  layout/init.lua  - Layout module entry
  layout/stack.lua - Window geometry: positioning, sizing, reflow
  borders.lua      - Border character definitions
  highlights.lua   - Highlight group setup
plugin/termite.lua - Autoloaded: autocmds and user commands
spec/              - Tests using Plenary.nvim busted framework
```

## Commands

```bash
make test              # Run all tests
make test-file FILE=   # Run specific test file
make lint              # Run luacheck linter
make format            # Format code with stylua
make check             # Run format, lint, and test
```

## Code Style

### Formatting

**StyLua** handles all formatting via `.stylua.toml`:
- Column width: 120
- Indent: Tabs (width 1)
- Quote style: AutoPreferDouble
- Call parentheses: Always
- Syntax: Lua52
- Never manually format; always run `make format`

### Module Structure

```lua
-- termite.nvim
-- Brief description

local config = require("termite.config")
local M = {}

-- Section {{{

M.public_function = function()
	-- implementation
end

-- Helper functions {{{
local function helper()
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

Group all `require` at top. Use `local M = require("termite.module")` pattern.

### Comments

- **NO inline comments** - code should be self-documenting
- File header: `-- termite.nvim` + brief description
- Use fold markers `-- {{{` and `-- }}}` for organization
- End-of-file: `-- vim: foldmethod=marker:foldmarker={{{,}}}:foldlevel=0`
- NOTE comments acceptable for explaining non-obvious behavior

### Error Handling

Always validate handles before use:
```lua
if term.win and vim.api.nvim_win_is_valid(term.win) then
	-- safe to use term.win
end
```

Use `pcall()` for operations that might fail:
```lua
pcall(vim.api.nvim_win_set_cursor, win, { line_count, 0 })
```

Use `vim.schedule()` for operations after async callbacks:
```lua
vim.schedule(function()
	if buf and vim.api.nvim_buf_is_valid(buf) then
		vim.api.nvim_buf_delete(buf, { force = true })
	end
end)
```

### Neovim API Usage

- Prefer `vim.api.nvim_*` over deprecated `vim.fn.*`
- Use `vim.tbl_deep_extend("force", default, override)` for merging options
- Create autocmds with `vim.api.nvim_create_autocmd()`
- Use `vim.keymap.set()` with `buffer = bufnr` for buffer-local maps
- Apply window options via `vim.wo[win][opt] = val`

### Terminal Operations

- Terminal buffers: scratch buffers (`nvim_create_buf(false, true)`)
- Windows: floating windows with `nvim_open_win()`, `relative = "editor"`
- Shell process: `vim.fn.jobstart(shell, { term = true, on_exit = ... })`
- Cleanup: BufWipeout autocmd removes from terminal stack

### Configuration

- Default values in module-level `DEFAULTS` table
- `M.setup(opts)` merges with `vim.tbl_deep_extend("force", ...)`
- Access via `require("termite.config").values`

### Testing

Tests use Plenary.nvim with busted framework:

Reset modules in `before_each` for fresh state:
```lua
before_each(function()
	package.loaded["termite.config"] = nil
	config = require("termite.config")
end)
```

- Use assertions: `assert.are.equal()`, `assert.are.same()`
- Group with `describe()` and `it()`

### Key Principles

1. **State is centralized** in `state.lua` - terminals, visibility flags, editor window ref
2. **Layout logic is pure** in `layout/stack.lua` - no side effects, returns config tables
3. **Terminal lifecycle** in `terminal.lua` - creates, shows, hides, closes terminals
4. **Public API** in `init.lua` - coordinates other modules, handles user actions
5. **Autoload behavior** in `plugin/termite.lua` - user commands and global autocmds

## Git Commit Style

Follow Conventional Commits with scope:

- `feat(component)` - New feature (e.g., `feat(terminal) add winbar`)
- `fix(component)` - Bug fix (e.g., `fix(layout) corner borders`)
- `docs:` - Documentation only
- `refactor(component)` - Code restructuring without behavior change
- `test(component)` - Test additions or fixes
- `chore:` - Build/tooling changes

Scope examples: `terminal`, `layout`, `config`, `state`, `highlights`, `keymaps`

## CI Workflow

CI runs on push/PR to main branch:
- Format check with StyLua
- Lint with luacheck
- Tests with Plenary

Run `make check` locally before pushing.
