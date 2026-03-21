-- termite.nvim
-- Stacking float terminal manager for Neovim.
--
-- Public API:
--   require("termite").setup(opts)          Configure the plugin.
--   require("termite").toggle()             Toggle all terminals (show/hide).
--   require("termite").create()             Create a new terminal.
--   require("termite").focus_next()         Focus next terminal in stack.
--   require("termite").focus_prev()         Focus previous terminal in stack.
--   require("termite").focus_editor()       Focus editor window.
--   require("termite").focus_terminals()    Focus the terminal stack.
--   require("termite").close_current()      Close the focused terminal.
--   require("termite").toggle_maximize()    Maximize/restore focused terminal.
--   require("termite").split_up()           Split pane upward (tmux layout).
--   require("termite").split_down()         Split pane downward (tmux layout).
--   require("termite").split_left()         Split pane leftward (tmux layout).
--   require("termite").split_right()        Split pane rightward (tmux layout).
--   require("termite").focus_up()           Focus pane above (tmux layout).
--   require("termite").focus_down()         Focus pane below (tmux layout).
--   require("termite").focus_left()         Focus pane to the left (tmux layout).
--   require("termite").focus_right()        Focus pane to the right (tmux layout).

local config = require("termite.config")
local highlights = require("termite.highlights")
local layout = require("termite.layout")
local state = require("termite.state")
local terminal = require("termite.terminal")

local M = {}

-- Configuration {{{

M.setup = function(opts)
	config.setup(opts)

	-- Set up highlights AFTER config is merged, so user values are available.
	highlights.setup()

	local km = config.values.keymaps
	if km.toggle then
		vim.keymap.set("n", km.toggle, function()
			M.toggle()
		end, { desc = "Termite: Toggle" })
	end
	if km.create then
		vim.keymap.set("n", km.create, function()
			M.create()
		end, { desc = "Termite: Create" })
	end
end

-- }}}

-- Helpers {{{

-- Find the index of the currently focused terminal (stack layout).
local function get_focused_index()
	local current_win = vim.api.nvim_get_current_win()
	for i, term in ipairs(state.terminals) do
		if term.win == current_win then
			return i
		end
	end
	return nil
end

-- Find the term_id of the currently focused terminal (tmux layout).
local function get_focused_term_id()
	local current_win = vim.api.nvim_get_current_win()
	for _, term in ipairs(state.terminals) do
		if term.win == current_win then
			return term.term_id
		end
	end
	return nil
end

-- Store the current window as the last editor window (if it's not a terminal).
local function save_editor_window()
	local win = vim.api.nvim_get_current_win()
	local buf = vim.api.nvim_win_get_buf(win)
	local bt = vim.bo[buf].buftype
	if bt ~= "terminal" then
		state.last_editor_winnr = win
	end
end

-- Update border highlights for all terminals based on focus.
local function update_border_highlights()
	local current_win = vim.api.nvim_get_current_win()
	for _, term in ipairs(state.terminals) do
		if term.win and vim.api.nvim_win_is_valid(term.win) then
			local hl_type
			if #state.terminals == 1 then
				hl_type = "single"
			elseif term.win == current_win then
				hl_type = "active"
			else
				hl_type = "inactive"
			end
			layout.update_border_highlight(term, hl_type)
		end
	end
end

-- Restore all hidden siblings when exiting maximized state (stack layout).
local function restore_from_maximized()
	state.maximized_idx = nil
	for i, term in ipairs(state.terminals) do
		if not term.win or not vim.api.nvim_win_is_valid(term.win) then
			local win_config = layout.get_win_config(i, #state.terminals)
			term.config = win_config
			terminal.show(term)
		end
	end
	update_border_highlights()
end

-- Focus the saved editor window.
local function focus_editor_window()
	if state.last_editor_winnr and vim.api.nvim_win_is_valid(state.last_editor_winnr) then
		vim.api.nvim_set_current_win(state.last_editor_winnr)
	end
end

-- }}}

-- Terminal actions {{{

-- Remove a terminal from the stack by reference and reflow remaining.
-- NOTE: Called from BufWipeout autocmd (e.g., when shell process exits).
M.remove_terminal = function(term)
	if config.values.layout == "tmux" then
		-- Tmux layout: use tree-based removal.
		local _, sibling_term_id = layout.remove(term.term_id)

		-- Remove from terminals list.
		for i, t in ipairs(state.terminals) do
			if t == term then
				table.remove(state.terminals, i)
				break
			end
		end

		if #state.terminals == 0 then
			state.visible = false
			state.pane_tree = nil
			focus_editor_window()
		elseif state.visible then
			layout.reflow()
			-- Always focus the sibling when a terminal closes (shell exit via <C-d>).
			-- Don't check last_focused_term_id because Neovim auto-switches focus on BufWipeout.
			local focused = false
			if sibling_term_id then
				for _, t in ipairs(state.terminals) do
					if t.term_id == sibling_term_id and t.win and vim.api.nvim_win_is_valid(t.win) then
						vim.api.nvim_set_current_win(t.win)
						state.last_focused_term_id = sibling_term_id
						focused = true
						break
					end
				end
			end
			-- Fallback: focus any available terminal if sibling not found.
			if not focused then
				for _, t in ipairs(state.terminals) do
					if t.win and vim.api.nvim_win_is_valid(t.win) then
						vim.api.nvim_set_current_win(t.win)
						state.last_focused_term_id = t.term_id
						break
					end
				end
			end
		end
		return
	end

	-- Stack layout: traditional removal.
	local removed_idx = nil
	for i, t in ipairs(state.terminals) do
		if t == term then
			removed_idx = i
			table.remove(state.terminals, i)
			break
		end
	end

	-- If the maximized terminal was removed, restore all siblings.
	if state.maximized_idx then
		if removed_idx and removed_idx == state.maximized_idx then
			restore_from_maximized()
		elseif removed_idx and removed_idx < state.maximized_idx then
			-- Adjust maximized_idx since an earlier terminal was removed.
			state.maximized_idx = state.maximized_idx - 1
		end
	end

	if #state.terminals == 0 then
		state.visible = false
		focus_editor_window()
	elseif state.visible then
		layout.reflow()
		local focus_idx = removed_idx and removed_idx > 1 and removed_idx - 1 or 1
		focus_idx = math.min(focus_idx, #state.terminals)
		local focus_term = state.terminals[focus_idx]
		if focus_term and focus_term.win and vim.api.nvim_win_is_valid(focus_term.win) then
			vim.api.nvim_set_current_win(focus_term.win)
		end
		update_border_highlights()
	end
end

-- Show all hidden terminals (stack layout).
local function show_all_stack()
	state.maximized_idx = nil
	for i, term in ipairs(state.terminals) do
		local win_config = layout.get_win_config(i, #state.terminals)
		term.config = win_config
		if not term.win or not vim.api.nvim_win_is_valid(term.win) then
			terminal.show(term)
		end
	end

	state.visible = true
	layout.reflow()

	-- Focus the most recently focused terminal, or fall back to the last in the stack.
	if #state.terminals > 0 then
		local focus_idx = state.last_focused_idx or #state.terminals
		focus_idx = math.min(focus_idx, #state.terminals)
		local term = state.terminals[focus_idx]
		if term and term.win and vim.api.nvim_win_is_valid(term.win) then
			vim.api.nvim_set_current_win(term.win)
			state.last_focused_idx = focus_idx
			update_border_highlights()
			if config.values.start_insert then
				vim.cmd.startinsert()
			end
		end
	end
end

-- Hide all terminals (stack layout).
local function hide_all_stack()
	state.maximized_idx = nil
	for _, term in ipairs(state.terminals) do
		terminal.hide(term)
	end

	state.visible = false

	-- Return to the last editor window.
	if state.last_editor_winnr and vim.api.nvim_win_is_valid(state.last_editor_winnr) then
		vim.api.nvim_set_current_win(state.last_editor_winnr)
	end
end

-- }}}

-- Public API {{{

-- Toggle all terminals (show/hide). First call creates one.
-- Smart behavior: if terminals visible but focus is on editor, focus terminals instead of hiding.
M.toggle = function()
	save_editor_window()

	if config.values.layout == "tmux" then
		-- Tmux layout: toggle pane visibility.
		if not state.pane_tree then
			-- Create root terminal.
			layout.create_root()
			return
		end

		if state.visible then
			-- Check if focus is on a terminal.
			local focused_id = get_focused_term_id()
			if focused_id then
				-- Hide all.
				for _, term in ipairs(state.terminals) do
					terminal.hide(term)
				end
				state.visible = false
				focus_editor_window()
			else
				-- Focus terminals.
				M.focus_terminals()
			end
		else
			-- Show all.
			for _, term in ipairs(state.terminals) do
				if not term.win or not vim.api.nvim_win_is_valid(term.win) then
					terminal.show(term)
				end
			end
			state.visible = true
			layout.reflow()
			M.focus_terminals()
		end
		return
	end

	-- Stack layout: traditional toggle.
	if state.visible and #state.terminals > 0 then
		-- Check if any terminal window is actually open.
		local any_visible = false
		for _, term in ipairs(state.terminals) do
			if term.win and vim.api.nvim_win_is_valid(term.win) then
				any_visible = true
				break
			end
		end

		if any_visible then
			-- Check if focus is currently on a terminal.
			local focused_idx = get_focused_index()
			if focused_idx then
				-- Focus is on a terminal, hide them.
				hide_all_stack()
			else
				-- Focus is on editor, focus terminals instead.
				M.focus_terminals()
			end
		else
			show_all_stack()
		end
	elseif #state.terminals > 0 then
		show_all_stack()
	else
		terminal.create()
		state.last_focused_idx = #state.terminals
		update_border_highlights()
	end
end

-- Create a new terminal and add it to the stack.
M.create = function()
	if config.values.layout == "tmux" then
		-- Tmux layout: split down from current pane.
		if not state.pane_tree then
			return layout.create_root()
		end
		return M.split_down()
	end

	-- Stack layout: traditional create.
	-- If a terminal is maximized, restore all before adding a new one.
	if state.maximized_idx then
		restore_from_maximized()
	end

	-- Show existing hidden terminals before creating a new one.
	if #state.terminals > 0 and not state.visible then
		state.visible = true
		for _, term in ipairs(state.terminals) do
			if not term.win or not vim.api.nvim_win_is_valid(term.win) then
				terminal.show(term)
			end
		end
	end

	local term = terminal.create()
	state.last_focused_idx = #state.terminals
	update_border_highlights()
	return term
end

-- Focus the next terminal in the stack (wraps around).
M.focus_next = function()
	if config.values.layout == "tmux" then
		-- For tmux, use right/down navigation.
		if not layout.focus_down() then
			layout.focus_right()
		end
		return
	end

	if state.maximized_idx then
		return
	end

	local idx = get_focused_index()
	if not idx then
		return
	end

	local next_idx = idx % #state.terminals + 1
	local term = state.terminals[next_idx]
	if term and term.win and vim.api.nvim_win_is_valid(term.win) then
		vim.api.nvim_set_current_win(term.win)
		state.last_focused_idx = next_idx
		update_border_highlights()
		if config.values.start_insert then
			vim.cmd.startinsert()
		end
	end
end

-- Focus the previous terminal in the stack (wraps around).
M.focus_prev = function()
	if config.values.layout == "tmux" then
		-- For tmux, use left/up navigation.
		if not layout.focus_up() then
			layout.focus_left()
		end
		return
	end

	if state.maximized_idx then
		return
	end

	local idx = get_focused_index()
	if not idx then
		return
	end

	local prev_idx = (idx - 2) % #state.terminals + 1
	local term = state.terminals[prev_idx]
	if term and term.win and vim.api.nvim_win_is_valid(term.win) then
		vim.api.nvim_set_current_win(term.win)
		state.last_focused_idx = prev_idx
		update_border_highlights()
		if config.values.start_insert then
			vim.cmd.startinsert()
		end
	end
end

-- Focus the editor window, keeping terminals visible.
M.focus_editor = function()
	if state.last_editor_winnr and vim.api.nvim_win_is_valid(state.last_editor_winnr) then
		vim.api.nvim_set_current_win(state.last_editor_winnr)
		update_border_highlights()
		return
	end

	-- Fallback: find any non-terminal, non-floating window.
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(win)
		local bt = vim.bo[buf].buftype
		local win_config = vim.api.nvim_win_get_config(win)
		if bt ~= "terminal" and win_config.relative == "" then
			vim.api.nvim_set_current_win(win)
			update_border_highlights()
			return
		end
	end
end

-- Focus the terminal stack (focuses the last focused terminal, or the last in the stack).
M.focus_terminals = function()
	if not state.visible or #state.terminals == 0 then
		return
	end

	if config.values.layout == "tmux" then
		local focus_id = state.last_focused_term_id
		for _, term in ipairs(state.terminals) do
			if term.term_id == focus_id then
				if term.win and vim.api.nvim_win_is_valid(term.win) then
					vim.api.nvim_set_current_win(term.win)
					if config.values.start_insert then
						vim.cmd.startinsert()
					end
				end
				return
			end
		end
		-- Fallback: focus first available.
		for _, term in ipairs(state.terminals) do
			if term.win and vim.api.nvim_win_is_valid(term.win) then
				vim.api.nvim_set_current_win(term.win)
				state.last_focused_term_id = term.term_id
				if config.values.start_insert then
					vim.cmd.startinsert()
				end
				return
			end
		end
		return
	end

	local focus_idx = state.last_focused_idx or #state.terminals
	focus_idx = math.min(focus_idx, #state.terminals)
	local term = state.terminals[focus_idx]
	if term and term.win and vim.api.nvim_win_is_valid(term.win) then
		vim.api.nvim_set_current_win(term.win)
		update_border_highlights()
		if config.values.start_insert then
			vim.cmd.startinsert()
		end
	end
end

-- Close the currently focused terminal and remove it from the stack.
M.close_current = function()
	if config.values.layout == "tmux" then
		local term_id = get_focused_term_id()
		if not term_id then
			return
		end

		-- Find terminal entry.
		local term = nil
		for _, t in ipairs(state.terminals) do
			if t.term_id == term_id then
				term = t
				break
			end
		end

		if not term then
			return
		end

		-- Remove from tree.
		layout.remove(term_id)

		-- Remove from list and close.
		for i, t in ipairs(state.terminals) do
			if t == term then
				table.remove(state.terminals, i)
				break
			end
		end
		terminal.close(term)

		if #state.terminals == 0 then
			state.visible = false
			state.pane_tree = nil
			focus_editor_window()
		elseif state.visible then
			layout.reflow()
			-- Try to focus an adjacent pane.
			for _, t in ipairs(state.terminals) do
				if t.win and vim.api.nvim_win_is_valid(t.win) then
					vim.api.nvim_set_current_win(t.win)
					state.last_focused_term_id = t.term_id
					break
				end
			end
		end
		return
	end

	-- Stack layout: traditional close.
	local idx = get_focused_index()
	if not idx then
		return
	end

	local was_maximized = state.maximized_idx == idx
	local term = state.terminals[idx]

	-- Determine which terminal to focus after closing.
	local next_idx = nil
	if #state.terminals > 1 then
		next_idx = idx <= #state.terminals - 1 and idx or idx - 1
	end

	-- Remove from stack first, then close.
	table.remove(state.terminals, idx)
	if was_maximized then
		state.maximized_idx = nil
	elseif state.maximized_idx and idx < state.maximized_idx then
		state.maximized_idx = state.maximized_idx - 1
	end
	terminal.close(term)

	if #state.terminals == 0 then
		state.visible = false
		if state.last_editor_winnr and vim.api.nvim_win_is_valid(state.last_editor_winnr) then
			vim.api.nvim_set_current_win(state.last_editor_winnr)
		end
	elseif state.visible then
		-- If the maximized terminal was closed, re-show all hidden siblings.
		if was_maximized then
			restore_from_maximized()
		end
		layout.reflow()
		if next_idx then
			local next_term = state.terminals[next_idx]
			if next_term and next_term.win and vim.api.nvim_win_is_valid(next_term.win) then
				vim.api.nvim_set_current_win(next_term.win)
			end
		end
		update_border_highlights()
	end
end

-- Maximize the focused terminal or restore if already maximized.
M.toggle_maximize = function()
	if config.values.layout == "tmux" then
		local term_id = get_focused_term_id()
		if not term_id then
			return
		end
		layout.toggle_maximize(term_id)
		return
	end

	local idx = get_focused_index()
	if not idx then
		return
	end

	if state.maximized_idx then
		-- Restore: re-show all hidden siblings.
		restore_from_maximized()
		layout.reflow()
		-- Re-focus the terminal that was maximized.
		local term = state.terminals[idx]
		if term and term.win and vim.api.nvim_win_is_valid(term.win) then
			vim.api.nvim_set_current_win(term.win)
			if config.values.start_insert then
				vim.cmd.startinsert()
			end
		end
		update_border_highlights()
	else
		-- Maximize: hide all siblings, expand focused terminal to full height.
		state.maximized_idx = idx
		for i, term in ipairs(state.terminals) do
			if i ~= idx then
				terminal.hide(term)
			end
		end
		-- Resize the maximized terminal to full height (index 1 of 1).
		local term = state.terminals[idx]
		if term and term.win and vim.api.nvim_win_is_valid(term.win) then
			local win_config = layout.get_win_config(1, 1)
			layout.apply_config(term, win_config)
			if config.values.start_insert then
				vim.cmd.startinsert()
			end
		end
		update_border_highlights()
	end
end

-- Split panes in cardinal directions (tmux layout).
M.split_up = function()
	layout.split_up()
end

M.split_down = function()
	layout.split_down()
end

M.split_left = function()
	layout.split_left()
end

M.split_right = function()
	layout.split_right()
end

-- Focus adjacent panes in cardinal directions.
M.focus_up = function()
	layout.focus_up()
end

M.focus_down = function()
	layout.focus_down()
end

M.focus_left = function()
	layout.focus_left()
end

M.focus_right = function()
	layout.focus_right()
end

-- }}}

return M

-- vim: foldmethod=marker:foldmarker={{{,}}}:foldlevel=0
