-- termite.nvim
-- Terminal creation, lifecycle, and buffer management.

local config = require("termite.config")
local state = require("termite.state")
local layout = require("termite.layout")

local M = {}

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
end

-- Create a new terminal. Opens a float window, starts a shell, sets up keymaps and
-- cleanup autocmds. Returns the terminal entry table { buf, win, config }.
M.create = function()
	local count = state.next_count
	state.next_count = state.next_count + 1

	local total = #state.terminals + 1

	-- Reflow existing terminals first to make room for the new one. This avoids a
	-- visual glitch where the existing terminals momentarily overlap with the new one
	-- before being resized.
	for i, t in ipairs(state.terminals) do
		if t.win and vim.api.nvim_win_is_valid(t.win) then
			local cfg = layout.get_win_config(i, total)
			layout.apply_config(t, cfg)
		end
	end

	local win_config = layout.get_win_config(total, total)

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
	vim.fn.jobstart(shell, {
		term = true,
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
	}

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
