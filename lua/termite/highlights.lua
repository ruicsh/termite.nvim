-- termite.nvim
-- Highlight group definitions.

local M = {}

-- Highlight groups for terminal window borders.
M.BORDER_ACTIVE = "TermiteBorder"
M.BORDER_INACTIVE = "TermiteBorderNC"

-- Set up default highlight groups with default = true so they can be overridden
-- by colorschemes or user configuration.
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
end

return M

-- vim: foldmethod=marker:foldmarker={{{,}}}:foldlevel=0
