-- termite.nvim
-- Window geometry: positioning, sizing, and reflow.

local config = require("termite.config")
local highlights = require("termite.highlights")
local state = require("termite.state")

local M = {}

-- Build a border array with highlight groups.
-- border: the base border array (array of chars)
-- position: "left", "right", "top", or "bottom"
-- hl_type: "active", "inactive", or "single"
-- Returns a border array where each element is either a char or {char, highlight}
M.build_highlighted_border = function(border, position, hl_type)
	local hl_single = highlights.resolve_hl(config.values.highlights.border_single, highlights.BORDER_SINGLE)
	local hl_active = highlights.resolve_hl(config.values.highlights.border_active, highlights.BORDER_ACTIVE)
	local hl_inactive = highlights.resolve_hl(config.values.highlights.border_inactive, highlights.BORDER_INACTIVE)

	local result = {}

	-- Determine which border indices face the editor (outer edge)
	-- Only highlight straight lines, not corners
	local outer_indices = {}
	if position == "left" then
		-- Right edge only (not corners)
		outer_indices = { [4] = true }
	elseif position == "right" then
		-- Left edge only (not corners)
		outer_indices = { [8] = true }
	elseif position == "top" then
		-- Bottom edge only (not corners)
		outer_indices = { [6] = true }
	elseif position == "bottom" then
		-- Top edge only (not corners)
		outer_indices = { [2] = true }
	end

	-- Convert all border elements to tuples with appropriate highlights
	for i, char in ipairs(border) do
		if char and char ~= "" then
			local is_outer = outer_indices[i]
			local hl
			if hl_type == "single" then
				hl = hl_single
			elseif hl_type == "active" and is_outer then
				hl = hl_active
			else
				hl = hl_inactive
			end
			result[i] = { char, hl }
		else
			result[i] = char
		end
	end

	return result
end

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

	local position = opts.position
	local chars = config.get_border_chars()

	-- Vertical stacking (left/right): terminals stack from top to bottom.
	if position == "left" or position == "right" then
		local width = math.floor(editor_width * opts.width)

		-- Every terminal has a bottom border row: separators between stacked terminals,
		-- and an invisible (space) row for the last terminal.
		local border_rows = total
		local usable_height = editor_height - border_rows
		local each_height = math.floor(usable_height / total)

		-- Accumulate row position, accounting for borders of previous terminals.
		local row = (index - 1) * (each_height + 1)

		-- Last terminal gets any remaining height to avoid a gap at the bottom.
		local height = each_height
		if index == total then
			height = usable_height - (each_height * (total - 1))
		end

		-- Border configuration: vertical borders on left/right, horizontal border at bottom.
		local border
		if index < total then
			if position == "left" then
				border = { "", "", chars.vertical, chars.vertical, chars.vertical_right, chars.horizontal, "", "" }
			else
				border = { "", "", "", "", chars.horizontal, chars.horizontal, chars.vertical_left, chars.vertical }
			end
		else
			-- Last terminal: no bottom border.
			if position == "left" then
				border = { "", "", chars.vertical, chars.vertical, " ", " ", "", "" }
			else
				border = { "", "", "", "", " ", " ", " ", chars.vertical }
			end
		end

		return {
			anchor = position == "left" and "NW" or "NE",
			border = border,
			col = position == "left" and 0 or editor_width,
			height = height,
			relative = "editor",
			row = row,
			style = "minimal",
			width = width,
			zindex = 50,
		}
	end

	-- Horizontal stacking (top/bottom): terminals stack from left to right.
	local height = math.floor(editor_height * opts.height)

	-- Every terminal has a right border column: separators between stacked terminals,
	-- and an invisible (space) column for the last terminal.
	local border_cols = total
	local usable_width = editor_width - border_cols
	local each_width = math.floor(usable_width / total)

	-- Accumulate column position, accounting for borders of previous terminals.
	local col = (index - 1) * (each_width + 1)

	-- Last terminal gets any remaining width to avoid a gap at the right edge.
	local width = each_width
	if index == total then
		width = usable_width - (each_width * (total - 1))
	end

	-- Border configuration: horizontal borders on top/bottom, vertical border at right.
	local border
	if index < total then
		if position == "top" then
			border = { "", "", chars.vertical, chars.vertical, chars.horizontal_up, chars.horizontal, chars.horizontal, "" }
		else
			border = { chars.horizontal, chars.horizontal, chars.horizontal_down, chars.vertical, "", "", "", "" }
		end
	else
		-- Last terminal: no right border.
		if position == "top" then
			border = { "", "", "", "", chars.horizontal, chars.horizontal, chars.horizontal, "" }
		else
			border = { chars.horizontal, chars.horizontal, chars.horizontal, "", "", "", "", "" }
		end
	end

	return {
		anchor = position == "top" and "NW" or "SW",
		border = border,
		col = col,
		height = height,
		relative = "editor",
		row = position == "top" and 0 or editor_height,
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

-- Update border highlights for a specific terminal based on active state.
-- Updates the window config border with highlight groups and applies it.
M.update_border_highlight = function(term, is_active)
	if not term.win or not vim.api.nvim_win_is_valid(term.win) then
		return
	end

	local opts = config.values
	local position = opts.position
	local chars = config.get_border_chars()

	-- Rebuild the base border (same logic as get_win_config)
	local border
	local total = #state.terminals
	local index = nil
	for i, t in ipairs(state.terminals) do
		if t == term then
			index = i
			break
		end
	end

	if not index then
		return
	end

	-- Build the base border array
	if position == "left" or position == "right" then
		if index < total then
			if position == "left" then
				border = { "", "", chars.vertical, chars.vertical, chars.vertical_right, chars.horizontal, "", "" }
			else
				border = { "", "", "", "", chars.horizontal, chars.horizontal, chars.vertical_left, chars.vertical }
			end
		else
			if position == "left" then
				border = { "", "", chars.vertical, chars.vertical, " ", " ", "", "" }
			else
				border = { "", "", "", "", " ", " ", " ", chars.vertical }
			end
		end
	else
		if index < total then
			if position == "top" then
				border = { "", "", chars.vertical, chars.vertical, chars.horizontal_up, chars.horizontal, chars.horizontal, "" }
			else
				border = { chars.horizontal, chars.horizontal, chars.horizontal_down, chars.vertical, "", "", "", "" }
			end
		else
			if position == "top" then
				border = { "", "", "", "", chars.horizontal, chars.horizontal, chars.horizontal, "" }
			else
				border = { chars.horizontal, chars.horizontal, chars.horizontal, "", "", "", "", "" }
			end
		end
	end

	-- Apply highlights to outer edge
	local highlighted_border = M.build_highlighted_border(border, position, is_active)

	-- Apply the new border config
	vim.api.nvim_win_set_config(term.win, {
		border = highlighted_border,
	})
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

-- vim: foldmethod=marker:foldmarker={{{,}}}:foldlevel=0
