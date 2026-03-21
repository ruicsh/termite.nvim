-- termite.nvim
-- Layout module - dynamically selects stack or tmux layout.

local config = require("termite.config")

local M = {}

-- Get the appropriate layout module.
local function get_layout_module()
	if config.values.layout == "tmux" then
		return require("termite.layout.tmux")
	end
	return require("termite.layout.stack")
end

-- Re-export all layout functions.
-- Core functions (both layouts).
M.get_win_config = function(...)
	return get_layout_module().get_win_config(...)
end

M.apply_config = function(...)
	return get_layout_module().apply_config(...)
end

M.reflow = function(...)
	return get_layout_module().reflow(...)
end

M.update_border_highlight = function(...)
	return get_layout_module().update_border_highlight(...)
end

-- Stack-specific function.
M.build_highlighted_border = function(...)
	return require("termite.layout.stack").build_highlighted_border(...)
end

-- Split functions.
M.split_up = function(...)
	return get_layout_module().split_up(...)
end

M.split_down = function(...)
	return get_layout_module().split_down(...)
end

M.split_left = function(...)
	return get_layout_module().split_left(...)
end

M.split_right = function(...)
	return get_layout_module().split_right(...)
end

-- Focus functions.
M.focus_up = function(...)
	return get_layout_module().focus_up(...)
end

M.focus_down = function(...)
	return get_layout_module().focus_down(...)
end

M.focus_left = function(...)
	return get_layout_module().focus_left(...)
end

M.focus_right = function(...)
	return get_layout_module().focus_right(...)
end

-- Tmux-specific functions (exposed for init.lua to use directly when needed).
M.create_root = function()
	return require("termite.layout.tmux").create_root()
end

M.remove = function(...)
	return require("termite.layout.tmux").remove(...)
end

M.toggle_maximize = function(...)
	return require("termite.layout.tmux").toggle_maximize(...)
end

M.find_adjacent = function(...)
	return require("termite.layout.tmux").find_adjacent(...)
end

return M

-- vim: foldmethod=marker:foldmarker={{{,}}}:foldlevel=0
