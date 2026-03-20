-- termite.nvim
-- Highlight group definitions.

local config = require("termite.config")

local M = {}

-- Highlight groups for terminal window borders.
M.BORDER_ACTIVE = "TermiteBorder"
M.BORDER_INACTIVE = "TermiteBorderNC"
M.BORDER_SINGLE = "TermiteBorderSingle"
M.WINBAR = "TermiteWinbar"

-- Set up default highlight groups with default = true so they can be overridden
-- by colorschemes or user configuration.
-- If user provides tables (e.g., { fg = "#00ff00", bg = "NONE" }), those take priority.
M.setup = function()
	-- Active terminal border - bright and visible
	vim.api.nvim_set_hl(0, M.BORDER_ACTIVE, {
		link = "FloatBorder",
		default = true,
	})

	-- Inactive terminal border - dimmed
	vim.api.nvim_set_hl(0, M.BORDER_INACTIVE, {
		link = "Comment",
		default = true,
	})

	-- Single terminal border - defaults to FloatBorder
	vim.api.nvim_set_hl(0, M.BORDER_SINGLE, {
		link = "FloatBorder",
		default = true,
	})

	-- Winbar - defaults to Normal
	vim.api.nvim_set_hl(0, M.WINBAR, {
		link = "Normal",
		default = true,
	})

	-- Apply user-provided highlight tables, if any.
	local active = config.values.highlights.border_active
	local inactive = config.values.highlights.border_inactive
	local single = config.values.highlights.border_single
	local winbar = config.values.highlights.winbar

	if type(active) == "table" then
		vim.api.nvim_set_hl(0, M.BORDER_ACTIVE, active)
	end
	if type(inactive) == "table" then
		vim.api.nvim_set_hl(0, M.BORDER_INACTIVE, inactive)
	end
	if type(single) == "table" then
		vim.api.nvim_set_hl(0, M.BORDER_SINGLE, single)
	end
	if type(winbar) == "table" then
		vim.api.nvim_set_hl(0, M.WINBAR, winbar)
	end
end

-- Resolve a highlight config value to a highlight group name.
-- If it's a string, return it directly. If it's a table, return the group name.
M.resolve_hl = function(config_value, default_group)
	if type(config_value) == "string" then
		return config_value
	end
	-- For tables, return the default group name that would have been set up.
	return default_group
end

return M

-- vim: foldmethod=marker:foldmarker={{{,}}}:foldlevel=0
