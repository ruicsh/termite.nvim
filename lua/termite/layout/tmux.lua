-- termite.nvim
-- Window geometry: positioning, sizing, and reflow for tmux layout.

local config = require("termite.config")
local constants = require("termite.constants")
local state = require("termite.state")
local terminal = require("termite.terminal")

local M = {}

-- Geometry helpers {{{

-- Get the editor dimensions accounting for UI elements.
local function get_editor_rect()
	local editor_width = vim.o.columns
	local editor_height = vim.o.lines - vim.o.cmdheight
	if vim.o.laststatus > 0 then
		editor_height = editor_height - 1
	end
	if vim.o.showtabline == 2 or (vim.o.showtabline == 1 and #vim.api.nvim_list_tabpages() > 1) then
		editor_height = editor_height - 1
	end

	local opts = config.values
	local position = opts.position
	local width = math.floor(editor_width * opts.width)
	local height = math.floor(editor_height * opts.height)

	-- Calculate root rectangle based on position.
	local root_row, root_col, root_width, root_height
	if position == "left" then
		root_row = 0
		root_col = 0
		root_width = width
		root_height = editor_height
	elseif position == "right" then
		root_row = 0
		root_col = editor_width - width
		root_width = width
		root_height = editor_height
	elseif position == "top" then
		root_row = 0
		root_col = 0
		root_width = editor_width
		root_height = height
	else -- bottom
		root_row = editor_height - height
		root_col = 0
		root_width = editor_width
		root_height = height
	end

	return { row = root_row, col = root_col, width = root_width, height = root_height }
end

-- Build border array for a pane based on its geometry and root position.
-- Uses all_geometries to detect neighbors and determine which inner edges to draw.
-- Border ownership rule: each pane draws its right and bottom edges.
-- Returns border array with all edges that should be visible.
local function build_pane_border(geom, root_rect, position, all_geometries)
	local chars = config.get_border_chars()

	-- Determine which edge is the outer edge based on position.
	-- This is the edge that faces the editor.
	local outer_left, outer_right, outer_top, outer_bottom = false, false, false, false

	if position == "right" then
		outer_left = geom.col == root_rect.col
	elseif position == "left" then
		outer_right = geom.col + geom.width == root_rect.col + root_rect.width
	elseif position == "top" then
		outer_bottom = geom.row + geom.height == root_rect.row + root_rect.height
	else -- bottom
		outer_top = geom.row == root_rect.row
	end

	-- Determine which inner edges exist.
	-- Inner edges are shared boundaries with other panes.
	-- Each pane draws all edges that border another pane (or the outer edge).
	local inner_left, inner_right, inner_top, inner_bottom = false, false, false, false

	-- Track the specific neighbors found for T-junction detection (above/below only)
	local neighbor_above, neighbor_below = nil, nil

	if all_geometries then
		local row_start, row_end = geom.row, geom.row + geom.height
		local col_start, col_end = geom.col, geom.col + geom.width

		-- Check for pane directly to the LEFT (other pane's right edge matches this left edge)
		for _, other_geom in pairs(all_geometries) do
			if other_geom.col + other_geom.width == geom.col then
				local other_row_start, other_row_end = other_geom.row, other_geom.row + other_geom.height
				if other_row_start < row_end and other_row_end > row_start then
					inner_left = true
					break
				end
			end
		end

		-- Check for pane directly to the RIGHT (other pane's left edge matches this right edge)
		local right_edge = geom.col + geom.width
		for _, other_geom in pairs(all_geometries) do
			if other_geom.col == right_edge then
				local other_row_start, other_row_end = other_geom.row, other_geom.row + other_geom.height
				if other_row_start < row_end and other_row_end > row_start then
					inner_right = true
					break
				end
			end
		end

		-- Check for pane directly ABOVE (other pane's bottom edge matches this top edge)
		for _, other_geom in pairs(all_geometries) do
			if other_geom.row + other_geom.height == geom.row then
				local other_col_start, other_col_end = other_geom.col, other_geom.col + other_geom.width
				if other_col_start < col_end and other_col_end > col_start then
					inner_top = true
					neighbor_above = other_geom
					break
				end
			end
		end

		-- Check for pane directly BELOW (other pane's top edge matches this bottom edge)
		local bottom_edge = geom.row + geom.height
		for _, other_geom in pairs(all_geometries) do
			if other_geom.row == bottom_edge then
				local other_col_start, other_col_end = other_geom.col, other_geom.col + other_geom.width
				if other_col_start < col_end and other_col_end > col_start then
					inner_bottom = true
					neighbor_below = other_geom
					break
				end
			end
		end
	end

	-- Build border array: {top-left, top, top-right, right, bottom-right, bottom, bottom-left, left}
	local border = { "", "", "", "", "", "", "", "" }

	-- Draw all edges (outer or inner)
	if outer_left or inner_left then
		border[constants.BORDER_LEFT] = chars.vertical
	end
	if outer_right or inner_right then
		border[constants.BORDER_RIGHT] = chars.vertical
	end
	if outer_top or inner_top then
		border[constants.BORDER_TOP] = chars.horizontal
	end
	if outer_bottom or inner_bottom then
		border[constants.BORDER_BOTTOM] = chars.horizontal
	end

	-- Corner handling - determine correct junction character based on which edges exist
	-- For inner+inner corners, check if the corner neighbor extends past (T-junction) or not (cross)

	-- top-left corner
	if (outer_top or inner_top) and (outer_left or inner_left) then
		if outer_top and outer_left then
			border[constants.BORDER_TOP_LEFT] = chars.top_left
		elseif outer_top and inner_left then
			border[constants.BORDER_TOP_LEFT] = chars.horizontal_down
		elseif inner_top and outer_left then
			border[constants.BORDER_TOP_LEFT] = chars.vertical_left
		elseif inner_top and inner_left then
			-- Both inner edges: check if neighbor above extends past left edge
			if neighbor_above and neighbor_above.col < geom.col then
				border[constants.BORDER_TOP_LEFT] = chars.horizontal_down
			else
				border[constants.BORDER_TOP_LEFT] = chars.cross
			end
		end
	end

	-- top-right corner
	if (outer_top or inner_top) and (outer_right or inner_right) then
		if outer_top and outer_right then
			border[constants.BORDER_TOP_RIGHT] = chars.top_right
		elseif outer_top and inner_right then
			border[constants.BORDER_TOP_RIGHT] = chars.horizontal_down
		elseif inner_top and outer_right then
			border[constants.BORDER_TOP_RIGHT] = chars.vertical_right
		elseif inner_top and inner_right then
			-- Both inner edges: check if neighbor above extends past right edge
			if neighbor_above and (neighbor_above.col + neighbor_above.width) > (geom.col + geom.width) then
				border[constants.BORDER_TOP_RIGHT] = chars.horizontal_down
			else
				border[constants.BORDER_TOP_RIGHT] = chars.cross
			end
		end
	end

	-- bottom-left corner
	if (outer_bottom or inner_bottom) and (outer_left or inner_left) then
		if outer_bottom and outer_left then
			border[constants.BORDER_BOTTOM_LEFT] = chars.bottom_left
		elseif outer_bottom and inner_left then
			border[constants.BORDER_BOTTOM_LEFT] = chars.horizontal_up
		elseif inner_bottom and outer_left then
			border[constants.BORDER_BOTTOM_LEFT] = chars.vertical_left
		elseif inner_bottom and inner_left then
			-- Both inner edges: check if neighbor below extends past left edge
			if neighbor_below and neighbor_below.col < geom.col then
				border[constants.BORDER_BOTTOM_LEFT] = chars.horizontal_up
			else
				border[constants.BORDER_BOTTOM_LEFT] = chars.cross
			end
		end
	end

	-- bottom-right corner
	if (outer_bottom or inner_bottom) and (outer_right or inner_right) then
		if outer_bottom and outer_right then
			border[constants.BORDER_BOTTOM_RIGHT] = chars.bottom_right
		elseif outer_bottom and inner_right then
			border[constants.BORDER_BOTTOM_RIGHT] = chars.horizontal_up
		elseif inner_bottom and outer_right then
			border[constants.BORDER_BOTTOM_RIGHT] = chars.vertical_right
		elseif inner_bottom and inner_right then
			-- Both inner edges: check if neighbor below extends past right edge
			if neighbor_below and (neighbor_below.col + neighbor_below.width) > (geom.col + geom.width) then
				border[constants.BORDER_BOTTOM_RIGHT] = chars.horizontal_up
			else
				border[constants.BORDER_BOTTOM_RIGHT] = chars.cross
			end
		end
	end

	return border
end

-- }}}}

-- Tree operations {{{

-- Find a leaf node by term_id in the tree.
-- Returns: node, parent_node, child_index
local function find_leaf(node, term_id, parent, child_idx)
	if node.type == "leaf" then
		if node.term_id == term_id then
			return node, parent, child_idx
		end
		return nil, nil, nil
	end

	for i, child in ipairs(node.children) do
		local found, found_parent, found_idx = find_leaf(child, term_id, node, i)
		if found then
			if found_parent then
				return found, found_parent, found_idx
			end
			-- Current node is the direct parent.
			return found, node, i
		end
	end
	return nil, nil, nil
end

-- Find terminal entry by term_id.
local function find_terminal(term_id)
	for _, term in ipairs(state.terminals) do
		if term.term_id == term_id then
			return term
		end
	end
	return nil
end

-- Get all leaf nodes with their geometry from the tree.
local function get_leaf_geometries(node, rect, result)
	result = result or {}
	if node.type == "leaf" then
		result[node.term_id] = rect
		return result
	end

	-- Split node: calculate children geometries.
	local first, second
	if node.dir == "v" then
		-- Vertical split: divide width.
		local first_width = math.floor(rect.width * node.ratio)
		first = { row = rect.row, col = rect.col, width = first_width, height = rect.height }
		second = { row = rect.row, col = rect.col + first_width, width = rect.width - first_width, height = rect.height }
	else
		-- Horizontal split: divide height.
		local first_height = math.floor(rect.height * node.ratio)
		first = { row = rect.row, col = rect.col, width = rect.width, height = first_height }
		second = { row = rect.row + first_height, col = rect.col, width = rect.width, height = rect.height - first_height }
	end

	get_leaf_geometries(node.children[1], first, result)
	get_leaf_geometries(node.children[2], second, result)
	return result
end

-- }}}}

-- Public API: Root and lifecycle {{{

-- Create the root terminal pane. Returns the new terminal entry.
M.create_root = function()
	local term_id = state.next_term_id
	state.next_term_id = state.next_term_id + 1

	-- Create root leaf node.
	state.pane_tree = { type = "leaf", term_id = term_id }

	-- Create terminal with full root geometry.
	local root_rect = get_editor_rect()
	local position = config.values.position
	local root_geoms = { [term_id] = root_rect }
	local border = build_pane_border(root_rect, root_rect, position, root_geoms)

	local term = terminal.create({
		term_id = term_id,
		row = root_rect.row,
		col = root_rect.col,
		width = root_rect.width,
		height = root_rect.height,
		border = border,
	})
	term.term_id = term_id

	state.visible = true
	state.last_focused_term_id = term_id

	return term
end

-- Split a pane in the given direction. Returns the new terminal entry.
-- direction: "up", "down", "left", "right"
M.split = function(term_id, direction)
	if not state.pane_tree then
		return nil
	end

	-- Find the leaf node to split.
	local leaf, parent, idx = find_leaf(state.pane_tree, term_id)
	if not leaf then
		return nil
	end

	-- If maximized, restore first.
	if state.maximized_term_id then
		M.toggle_maximize()
	end

	-- Create new term_id.
	local new_term_id = state.next_term_id
	state.next_term_id = state.next_term_id + 1

	-- Determine split direction and placement.
	-- For "up" and "down": split horizontally (h), dividing height.
	-- For "left" and "right": split vertically (v), dividing width.
	local split_dir = (direction == "up" or direction == "down") and "h" or "v"

	-- Create new split node.
	local new_leaf = { type = "leaf", term_id = new_term_id }
	local split_node
	if direction == "up" or direction == "left" then
		-- New pane comes first (top/left).
		split_node = { type = "split", dir = split_dir, ratio = 0.5, children = { new_leaf, leaf } }
	else
		-- New pane comes second (bottom/right).
		split_node = { type = "split", dir = split_dir, ratio = 0.5, children = { leaf, new_leaf } }
	end

	-- Replace leaf with split node in tree.
	if not parent then
		-- This is the root node.
		state.pane_tree = split_node
	elseif idx then
		parent.children[idx] = split_node
	end

	-- Get the current terminal to inherit cwd.
	local current_term = find_terminal(term_id)
	local cwd = current_term and current_term.cwd or vim.fn.getcwd()

	-- Calculate geometry for new terminal.
	local leaf_geoms = get_leaf_geometries(state.pane_tree, get_editor_rect())
	local geom = leaf_geoms[new_term_id]
	if not geom then
		return nil
	end

	-- Create new terminal.
	local term = terminal.create({
		term_id = new_term_id,
		cwd = cwd,
		row = geom.row,
		col = geom.col,
		width = geom.width,
		height = geom.height,
	})
	term.term_id = new_term_id
	term.cwd = cwd

	-- Reflow all panes to update geometries.
	M.reflow()

	-- Focus the new terminal.
	if term.win and vim.api.nvim_win_is_valid(term.win) then
		vim.api.nvim_set_current_win(term.win)
		state.last_focused_term_id = new_term_id
	end

	return term
end

-- Remove a terminal from the tree.
-- Returns: success (boolean), sibling_term_id (number|nil)
-- The sibling_term_id is the ID of the pane that should receive focus after removal.
M.remove = function(term_id)
	if not state.pane_tree then
		return false, nil
	end

	-- Find the leaf node.
	local leaf, parent, idx = find_leaf(state.pane_tree, term_id)
	if not leaf then
		return false, nil
	end

	if not parent then
		-- This is the root and only pane.
		state.pane_tree = nil
		state.visible = false
		state.maximized_term_id = nil
		state.last_focused_term_id = nil
		return true, nil
	end

	-- Get sibling to replace the split node.
	local sibling_idx = idx == 1 and 2 or 1
	local sibling = parent.children[sibling_idx]

	-- Find the split node's parent (grandparent of leaf).
	local split_node = parent

	local function find_parent_of(node, target)
		if node.type == "split" then
			for i, child in ipairs(node.children) do
				if child == target then
					return node, i
				end
				local gp, si = find_parent_of(child, target)
				if gp then
					return gp, si
				end
			end
		end
		return nil, nil
	end

	local grandparent, split_idx = find_parent_of(state.pane_tree, split_node)

	if not grandparent then
		-- Split node is root.
		state.pane_tree = sibling
	elseif split_idx then
		grandparent.children[split_idx] = sibling
	end

	-- Determine sibling term_id for focus (if sibling is a leaf)
	local sibling_term_id = sibling.type == "leaf" and sibling.term_id or nil

	-- Update focus tracking.
	if state.last_focused_term_id == term_id then
		state.last_focused_term_id = sibling_term_id
	end
	if state.maximized_term_id == term_id then
		state.maximized_term_id = nil
	end

	return true, sibling_term_id
end

-- }}}}

-- Public API: Navigation {{{

-- Find adjacent pane in given direction using spatial search.
-- Returns term_id of adjacent pane, or nil if none.
M.find_adjacent = function(from_term_id, direction)
	if not state.pane_tree then
		return nil
	end

	local leaf_geoms = get_leaf_geometries(state.pane_tree, get_editor_rect())
	local from_geom = leaf_geoms[from_term_id]
	if not from_geom then
		return nil
	end

	-- Calculate center of from pane.
	local from_center = {
		row = from_geom.row + from_geom.height / 2,
		col = from_geom.col + from_geom.width / 2,
	}

	-- Filter and find best candidate.
	local best_id = nil
	local best_dist = math.huge

	for term_id, geom in pairs(leaf_geoms) do
		if term_id ~= from_term_id then
			local candidate_center = {
				row = geom.row + geom.height / 2,
				col = geom.col + geom.width / 2,
			}

			-- Check if candidate is in the correct direction.
			local is_valid = false
			if direction == "up" then
				is_valid = geom.row + geom.height <= from_geom.row
			elseif direction == "down" then
				is_valid = geom.row >= from_geom.row + from_geom.height
			elseif direction == "left" then
				is_valid = geom.col + geom.width <= from_geom.col
			elseif direction == "right" then
				is_valid = geom.col >= from_geom.col + from_geom.width
			end

			if is_valid then
				-- Calculate distance (prefer closer panes).
				local drow = candidate_center.row - from_center.row
				local dcol = candidate_center.col - from_center.col
				local dist = math.sqrt(drow * drow + dcol * dcol)
				if dist < best_dist then
					best_dist = dist
					best_id = term_id
				end
			end
		end
	end

	return best_id
end

-- Focus adjacent pane in given direction.
-- direction: "up", "down", "left", "right"
M.focus_adjacent = function(direction)
	if not state.pane_tree then
		return false
	end

	-- Get current focused terminal.
	local current_win = vim.api.nvim_get_current_win()
	local current_term_id = nil
	for _, term in ipairs(state.terminals) do
		if term.win == current_win then
			current_term_id = term.term_id
			break
		end
	end

	if not current_term_id then
		return false
	end

	local adjacent_id = M.find_adjacent(current_term_id, direction)
	if not adjacent_id then
		return false
	end

	local adjacent_term = find_terminal(adjacent_id)
	if adjacent_term and adjacent_term.win and vim.api.nvim_win_is_valid(adjacent_term.win) then
		vim.api.nvim_set_current_win(adjacent_term.win)
		state.last_focused_term_id = adjacent_id
		if config.values.start_insert then
			vim.cmd.startinsert()
		end
		return true
	end

	return false
end

-- Split helpers for specific directions.
M.split_up = function()
	local current_win = vim.api.nvim_get_current_win()
	for _, term in ipairs(state.terminals) do
		if term.win == current_win then
			return M.split(term.term_id, "up")
		end
	end
	return nil
end

M.split_down = function()
	local current_win = vim.api.nvim_get_current_win()
	for _, term in ipairs(state.terminals) do
		if term.win == current_win then
			return M.split(term.term_id, "down")
		end
	end
	return nil
end

M.split_left = function()
	local current_win = vim.api.nvim_get_current_win()
	for _, term in ipairs(state.terminals) do
		if term.win == current_win then
			return M.split(term.term_id, "left")
		end
	end
	return nil
end

M.split_right = function()
	local current_win = vim.api.nvim_get_current_win()
	for _, term in ipairs(state.terminals) do
		if term.win == current_win then
			return M.split(term.term_id, "right")
		end
	end
	return nil
end

-- Focus helpers for specific directions.
M.focus_up = function()
	return M.focus_adjacent("up")
end

M.focus_down = function()
	return M.focus_adjacent("down")
end

M.focus_left = function()
	return M.focus_adjacent("left")
end

M.focus_right = function()
	return M.focus_adjacent("right")
end

-- }}}}

-- Public API: Geometry and reflow {{{

-- Get window config for a specific terminal.
M.get_win_config = function(term_id)
	if not state.pane_tree then
		return nil
	end

	local root_rect = get_editor_rect()
	local leaf_geoms = get_leaf_geometries(state.pane_tree, root_rect)
	local geom = leaf_geoms[term_id]
	if not geom then
		return nil
	end

	local position = config.values.position
	local border = build_pane_border(geom, root_rect, position, leaf_geoms)

	local win_config = {
		relative = "editor",
		row = geom.row,
		col = geom.col,
		width = geom.width,
		height = geom.height,
		anchor = "NW",
		style = "minimal",
		border = border or "none",
		zindex = 50,
	}
	return win_config
end

-- Apply window config to a terminal.
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

		-- Scroll viewport to the cursor after resize.
		local buf = vim.api.nvim_win_get_buf(term.win)
		local line_count = vim.api.nvim_buf_line_count(buf)
		pcall(vim.api.nvim_win_set_cursor, term.win, { line_count, 0 })
	end
end

-- Reflow all visible terminals.
M.reflow = function()
	if not state.pane_tree then
		return
	end
	if state.maximized_term_id then
		return
	end

	local leaf_geoms = get_leaf_geometries(state.pane_tree, get_editor_rect())

	for _, term in ipairs(state.terminals) do
		local geom = leaf_geoms[term.term_id]
		if geom and term.win and vim.api.nvim_win_is_valid(term.win) then
			local win_config = M.get_win_config(term.term_id)
			if win_config then
				M.apply_config(term, win_config)
			end
		end
	end
end

-- Update border highlight for tmux layout.
-- Applies the single border highlight to outer edge borders.
---@diagnostic disable-next-line: unused-local
M.update_border_highlight = function(term, _hl_type)
	if not term.win or not vim.api.nvim_win_is_valid(term.win) then
		return
	end

	if not state.pane_tree or state.maximized_term_id then
		return
	end

	local highlights = require("termite.highlights")
	local hl_single = highlights.resolve_hl(config.values.highlights.border_single, highlights.BORDER_SINGLE)

	local root_rect = get_editor_rect()
	local leaf_geoms = get_leaf_geometries(state.pane_tree, root_rect)
	local geom = leaf_geoms[term.term_id]
	if not geom then
		return
	end

	local position = config.values.position
	local border = build_pane_border(geom, root_rect, position, leaf_geoms)
	if not border then
		return
	end

	-- Apply highlight to all border characters
	local highlighted_border = {}
	for i, char in ipairs(border) do
		if char and char ~= "" then
			highlighted_border[i] = { char, hl_single }
		else
			highlighted_border[i] = char
		end
	end

	vim.api.nvim_win_set_config(term.win, {
		border = highlighted_border,
	})
end

-- }}}}

-- Public API: Zoom/Maximize {{{

-- Toggle maximize for a terminal.
M.toggle_maximize = function(term_id)
	if not state.pane_tree then
		return
	end

	if state.maximized_term_id == term_id then
		-- Restore all panes.
		state.maximized_term_id = nil
		M.reflow()
	else
		-- Maximize this pane.
		state.maximized_term_id = term_id

		-- Hide all other panes.
		for _, term in ipairs(state.terminals) do
			if term.term_id ~= term_id then
				terminal.hide(term)
			end
		end

		-- Expand maximized pane to full root rect.
		local root_rect = get_editor_rect()
		local maximized_term = find_terminal(term_id)
		if maximized_term and maximized_term.win and vim.api.nvim_win_is_valid(maximized_term.win) then
			local win_config = {
				relative = "editor",
				row = root_rect.row,
				col = root_rect.col,
				width = root_rect.width,
				height = root_rect.height,
				anchor = "NW",
				style = "minimal",
				border = "none",
				zindex = 50,
			}
			M.apply_config(maximized_term, win_config)
		end
	end
end

-- }}}}

-- Test exports {{{

M._test = {
	build_pane_border = build_pane_border,
	get_editor_rect = get_editor_rect,
	get_leaf_geometries = get_leaf_geometries,
	find_leaf = find_leaf,
}

-- }}}

return M

-- vim: foldmethod=marker:foldmarker={{{,}}}:foldlevel=0
