-- termite.nvim
-- Window geometry: positioning, sizing, and reflow.

local config = require("termite.config")
local state = require("termite.state")

local M = {}

-- Compute the floating window config for a terminal at the given index in a stack of
-- `total` terminals.
M.get_win_config = function(index, total)
	local opts = config.values
	local editor_width = vim.o.columns
	local editor_height = vim.o.lines - vim.o.cmdheight
	if vim.o.laststatus > 0 then
		editor_height = editor_height - 1
	end
	if vim.o.showtabline == 2 or (vim.o.showtabline == 1 and #vim.api.nvim_list_tabpages() > 1) then
		editor_height = editor_height - 1
	end
	local width = math.floor(editor_width * opts.width)

	-- Every terminal has a bottom border row: separators between stacked terminals,
	-- and an invisible (space) row for the last terminal. This prevents terminals from
	-- gaining/losing border rows when siblings are added or removed, which would cause
	-- the terminal emulator to detect a resize and shift the content.
	local border_rows = total
	local usable_height = editor_height - border_rows
	local each_height = math.floor(usable_height / total)

	-- Accumulate row position, accounting for borders of previous terminals.
	-- Each terminal occupies `each_height` content rows + 1 row for the bottom border.
	local row = (index - 1) * (each_height + 1)

	-- Last terminal gets any remaining height to avoid a gap at the bottom.
	local height = each_height
	if index == total then
		height = usable_height - (each_height * (total - 1))
	end

	-- Border: left border always, bottom separator between stacked terminals,
	-- invisible bottom border for the last terminal.
	local border
	if index < total then
		border = { "", "", "", "", opts.separator, opts.separator, opts.border, opts.border }
	else
		border = { "", "", "", "", " ", " ", " ", opts.border }
	end

	return {
		anchor = "NE",
		border = border,
		col = editor_width,
		height = height,
		relative = "editor",
		row = row,
		style = "minimal",
		width = width,
		zindex = 50,
	}
end

-- Apply a window config to a terminal entry. Updates both the Neovim window and the
-- stored config on the terminal entry, so re-showing the window uses the correct geometry.
M.apply_config = function(term, win_config)
	term.config = win_config

	if term.win and vim.api.nvim_win_is_valid(term.win) then
		vim.api.nvim_win_set_config(term.win, {
			anchor = win_config.anchor,
			border = win_config.border,
			col = win_config.col,
			height = win_config.height,
			relative = win_config.relative,
			row = win_config.row,
			width = win_config.width,
			zindex = win_config.zindex,
		})
		for opt, val in pairs(config.values.wo) do
			vim.wo[term.win][opt] = val
		end

		-- Scroll viewport to the cursor after resize to prevent content shift.
		local buf = vim.api.nvim_win_get_buf(term.win)
		local line_count = vim.api.nvim_buf_line_count(buf)
		pcall(vim.api.nvim_win_set_cursor, term.win, { line_count, 0 })
	end
end

-- Reposition and resize all visible terminals in the stack.
M.reflow = function()
	local total = #state.terminals
	if total == 0 then
		return
	end

	for i, term in ipairs(state.terminals) do
		if term.win and vim.api.nvim_win_is_valid(term.win) then
			local win_config = M.get_win_config(i, total)
			M.apply_config(term, win_config)
		end
	end
end

return M
