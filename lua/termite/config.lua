-- termite.nvim
-- Configuration defaults and setup.

local M = {}

local BORDER_STYLES = {
	light = { vertical = "│", horizontal = "─", vertical_left = "├", vertical_right = "┤" },
	heavy = { vertical = "┃", horizontal = "━", vertical_left = "┣", vertical_right = "┫" },
	double = { vertical = "║", horizontal = "═", vertical_left = "╠", vertical_right = "╣" },
	["double-dash"] = { vertical = "╎", horizontal = "╌", vertical_left = "╟", vertical_right = "╢" },
	["triple-dash"] = { vertical = "┆", horizontal = "┄", vertical_left = "┝", vertical_right = "┥" },
	["quadruple-dash"] = { vertical = "┊", horizontal = "┈", vertical_left = "┝", vertical_right = "┥" },
}

local DEFAULTS = {
	width = 0.5, -- Fraction of editor width.
	position = "right", -- Panel position: "left" or "right".
	border = "light", -- Border style: "light", "heavy", "double", "double-dash", "triple-dash", "quadruple-dash".
	shell = nil, -- Shell command (nil = default shell).
	start_insert = true, -- Enter insert mode when focusing a terminal.
	keymaps = {
		toggle = "<c-bslash>", -- Toggle all terminals (terminal mode).
		create = "<c-t>", -- Create new terminal.
		next = "<c-j>", -- Focus next terminal in stack.
		prev = "<c-k>", -- Focus previous terminal in stack.
		focus_editor = "<c-h>", -- Return focus to editor window.
		normal_mode = "<c-[>", -- Exit terminal insert mode.
		maximize = "<c-z>", -- Maximize/restore focused terminal.
		close = "q", -- Close current terminal (normal mode).
	},
	wo = { -- Window options applied to terminal windows.
		signcolumn = "yes:1",
	},
}

M.values = vim.deepcopy(DEFAULTS)

M.setup = function(opts)
	M.values = vim.tbl_deep_extend("force", vim.deepcopy(DEFAULTS), opts or {})
end

M.get_border_chars = function()
	return BORDER_STYLES[M.values.border] or BORDER_STYLES.light
end

return M
