-- termite.nvim
-- Autoloaded: autocmds and user commands.

local group = vim.api.nvim_create_augroup("termite/plugin", { clear = true })

-- Reflow or reposition terminals when the editor is resized.
vim.api.nvim_create_autocmd("VimResized", {
	group = group,
	callback = function()
		local state = require("termite.state")
		if not state.visible or #state.terminals == 0 then
			return
		end

		local layout = require("termite.layout")
		if state.maximized_idx then
			-- Only reposition the maximized terminal.
			local term = state.terminals[state.maximized_idx]
			if term and term.win and vim.api.nvim_win_is_valid(term.win) then
				local win_config = layout.get_win_config(1, 1)
				layout.apply_config(term, win_config)
			end
		else
			layout.reflow()
		end
	end,
})

-- Update border highlights when entering a terminal window.
vim.api.nvim_create_autocmd("WinEnter", {
	group = group,
	callback = function()
		local state = require("termite.state")
		local layout = require("termite.layout")
		if not state.visible or #state.terminals == 0 then
			return
		end

		local current_win = vim.api.nvim_get_current_win()
		local is_termite_terminal = false
		for _, term in ipairs(state.terminals) do
			if term.win == current_win then
				is_termite_terminal = true
				break
			end
		end

		if is_termite_terminal then
			local current_win_id = vim.api.nvim_get_current_win()
			for _, term in ipairs(state.terminals) do
				if term.win and vim.api.nvim_win_is_valid(term.win) then
					local is_active = term.win == current_win_id
					layout.update_border_highlight(term, is_active)
				end
			end
		end
	end,
})

-- User commands.
local SUBCOMMANDS = {
	toggle = "toggle",
	create = "create",
	maximize = "toggle_maximize",
	close = "close_current",
	next = "focus_next",
	prev = "focus_prev",
	editor = "focus_editor",
}

vim.api.nvim_create_user_command("Termite", function(opts)
	local termite = require("termite")
	local subcmd = opts.fargs[1] or "toggle"
	local fn_name = SUBCOMMANDS[subcmd]
	if fn_name and termite[fn_name] then
		termite[fn_name]()
	else
		vim.notify("Termite: unknown command '" .. subcmd .. "'", vim.log.levels.WARN)
	end
end, {
	nargs = "?",
	complete = function()
		return vim.tbl_keys(SUBCOMMANDS)
	end,
	desc = "Termite: stacking float terminal manager",
})
