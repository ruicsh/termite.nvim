-- termite.nvim
-- Terminal creation, lifecycle, and buffer management.

local config = require("termite.config")
local state = require("termite.state")
local layout = require("termite.layout")

local M = {}

-- Format cwd for display, shortening home directory.
local function format_cwd(cwd)
	local home = vim.fn.expand("~")
	if vim.startswith(cwd, home) then
		return "~" .. cwd:sub(#home + 1)
	end
	return cwd
end

-- Set the winbar for a terminal window using b:term_title.
local function set_winbar(term)
	if not config.values.winbar then
		return
	end
	if not term.win or not vim.api.nvim_win_is_valid(term.win) then
		return
	end

	local cwd = term.cwd and format_cwd(term.cwd) or "~"
	local hl = config.values.highlights.winbar
	vim.wo[term.win].winbar = "%#" .. hl .. "#  %{get(b:, 'term_title', '" .. cwd .. "')}"
end

-- Set up buffer-local keymaps for a terminal buffer.
M.setup_keymaps = function(bufnr)
	local opts = config.values
	local km = opts.keymaps
	local termite = require("termite")

	local function map(mode, lhs, rhs, desc)
		if lhs then
			vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = "Termite: " .. desc })
		end
	end

	map("t", km.toggle, function()
		termite.toggle()
	end, "Toggle")
	map("t", km.create, function()
		termite.create()
	end, "Create")
	map("t", km.next, function()
		termite.focus_next()
	end, "Focus next")
	map("t", km.prev, function()
		termite.focus_prev()
	end, "Focus prev")
	map("t", km.focus_editor, function()
		termite.focus_editor()
	end, "Focus editor")
	map("t", km.normal_mode, function()
		vim.cmd.stopinsert()
	end, "Normal mode")
	map("t", km.maximize, function()
		termite.toggle_maximize()
	end, "Maximize/restore")
	map("n", km.close, function()
		termite.close_current()
	end, "Close")
	-- Split panes (tmux layout).
	map("t", km.split_up, function()
		termite.split_up()
	end, "Split pane up")
	map("t", km.split_down, function()
		termite.split_down()
	end, "Split pane down")
	map("t", km.split_left, function()
		termite.split_left()
	end, "Split pane left")
	map("t", km.split_right, function()
		termite.split_right()
	end, "Split pane right")
	-- Focus adjacent panes (tmux layout).
	map("t", km.focus_up, function()
		termite.focus_up()
	end, "Focus pane up")
	map("t", km.focus_down, function()
		termite.focus_down()
	end, "Focus pane down")
	map("t", km.focus_left, function()
		termite.focus_left()
	end, "Focus pane left")
	map("t", km.focus_right, function()
		termite.focus_right()
	end, "Focus pane right")
end

-- Create a new terminal. Opens a float window, starts a shell, sets up keymaps and
-- cleanup autocmds. Returns the terminal entry table { buf, win, config }.
--
-- opts (optional table):
--   term_id: Unique terminal ID for tmux layout.
--   row, col, width, height: Geometry for tmux layout.
--   cwd: Working directory (defaults to current directory).
M.create = function(opts)
	opts = opts or {}

	local count = state.next_count
	state.next_count = state.next_count + 1

	local total = #state.terminals + 1

	-- Reflow existing terminals first to make room for the new one. This avoids a
	-- visual glitch where the existing terminals momentarily overlap with the new one
	-- before being resized. Only do this for stack layout.
	if config.values.layout ~= "tmux" then
		for i, t in ipairs(state.terminals) do
			if t.win and vim.api.nvim_win_is_valid(t.win) then
				local cfg = layout.get_win_config(i, total)
				layout.apply_config(t, cfg)
			end
		end
	end

	local win_config
	if opts.row and opts.col and opts.width and opts.height then
		-- Tmux layout: use provided geometry.
		win_config = {
			relative = "editor",
			row = opts.row,
			col = opts.col,
			width = opts.width,
			height = opts.height,
			anchor = "NW",
			style = "minimal",
			border = opts.border or "none",
			zindex = 50,
		}
	else
		-- Stack layout: compute from layout module.
		win_config = layout.get_win_config(total, total)
	end

	-- Create a scratch buffer for the terminal.
	local buf = vim.api.nvim_create_buf(false, true)

	-- Open a floating window with the computed geometry.
	local win = vim.api.nvim_open_win(buf, true, {
		anchor = win_config.anchor,
		border = win_config.border,
		col = win_config.col,
		height = win_config.height,
		relative = win_config.relative,
		row = win_config.row,
		style = win_config.style,
		width = win_config.width,
		zindex = win_config.zindex,
	})

	-- Apply window options.
	for opt, val in pairs(config.values.wo) do
		vim.wo[win][opt] = val
	end

	-- Start the shell inside the terminal buffer.
	local shell = config.values.shell or vim.o.shell
	local term_cwd = opts.cwd or vim.fn.getcwd()
	vim.fn.jobstart(shell, {
		term = true,
		cwd = term_cwd,
		on_exit = function()
			-- Wipe the buffer when the shell process exits. This triggers the BufWipeout
			-- autocmd below, which removes the terminal from the stack.
			vim.schedule(function()
				if buf and vim.api.nvim_buf_is_valid(buf) then
					vim.api.nvim_buf_delete(buf, { force = true })
				end
			end)
		end,
	})

	-- Build the terminal entry.
	local term = {
		buf = buf,
		win = win,
		config = win_config,
		count = count,
		cwd = term_cwd,
	}

	-- Assign term_id for tmux layout.
	if opts.term_id then
		term.term_id = opts.term_id
	end

	table.insert(state.terminals, term)
	state.visible = true

	-- Set up buffer-local keymaps.
	M.setup_keymaps(buf)

	-- Register cleanup: when the buffer is wiped (shell exits or :bwipeout), remove
	-- the terminal from the stack.
	vim.api.nvim_create_autocmd("BufWipeout", {
		buffer = buf,
		once = true,
		callback = function()
			require("termite").remove_terminal(term)
		end,
	})

	-- Set up winbar.
	if config.values.winbar then
		set_winbar(term)
	end

	-- Enter insert mode in the new terminal.
	if config.values.start_insert then
		vim.cmd.startinsert()
	end

	return term
end

-- Show a hidden terminal (buffer alive, window closed). Opens a new float window.
M.show = function(term)
	if not term.buf or not vim.api.nvim_buf_is_valid(term.buf) then
		return
	end

	-- Don't re-show if already visible.
	if term.win and vim.api.nvim_win_is_valid(term.win) then
		return
	end

	local win = vim.api.nvim_open_win(term.buf, false, {
		anchor = term.config.anchor,
		border = term.config.border,
		col = term.config.col,
		height = term.config.height,
		relative = term.config.relative,
		row = term.config.row,
		style = term.config.style or "minimal",
		width = term.config.width,
		zindex = term.config.zindex,
	})

	term.win = win

	-- Apply window options.
	for opt, val in pairs(config.values.wo) do
		vim.wo[win][opt] = val
	end

	-- Set up winbar.
	if config.values.winbar then
		set_winbar(term)
	end
end

-- Hide a terminal (close the window, keep the buffer alive).
M.hide = function(term)
	if term.win and vim.api.nvim_win_is_valid(term.win) then
		vim.api.nvim_win_close(term.win, true)
	end
	term.win = nil
end

-- Close a terminal (close the window and wipe the buffer).
M.close = function(term)
	if term.win and vim.api.nvim_win_is_valid(term.win) then
		vim.api.nvim_win_close(term.win, true)
		term.win = nil
	end
	if term.buf and vim.api.nvim_buf_is_valid(term.buf) then
		vim.api.nvim_buf_delete(term.buf, { force = true })
		term.buf = nil
	end
end

return M
