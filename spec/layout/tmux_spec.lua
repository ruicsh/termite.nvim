describe("layout.tmux module", function()
	local tmux
	local config
	local state

	local saved_columns, saved_lines, saved_cmdheight, saved_laststatus, saved_showtabline

	local function setup_vim_mock(columns, lines, cmdheight, laststatus, showtabline)
		vim.o.columns = columns or 100
		vim.o.lines = lines or 50
		vim.o.cmdheight = cmdheight or 1
		vim.o.laststatus = laststatus or 2
		vim.o.showtabline = showtabline or 1
	end

	local function reset_state()
		state.pane_tree = nil
		state.terminals = {}
		state.next_term_id = 1
		state.next_count = 1
		state.visible = false
		state.last_focused_term_id = nil
		state.maximized_term_id = nil
	end

	before_each(function()
		package.loaded["termite.config"] = nil
		package.loaded["termite.state"] = nil
		package.loaded["termite.terminal"] = nil
		package.loaded["termite.layout"] = nil
		package.loaded["termite.layout.tmux"] = nil
		package.loaded["termite.layout.stack"] = nil

		-- Save original values
		saved_columns = vim.o.columns
		saved_lines = vim.o.lines
		saved_cmdheight = vim.o.cmdheight
		saved_laststatus = vim.o.laststatus
		saved_showtabline = vim.o.showtabline

		config = require("termite.config")
		-- Set config BEFORE requiring other modules
		config.setup({ layout = "tmux", position = "right", width = 0.5, height = 0.5 })

		state = require("termite.state")
		tmux = require("termite.layout.tmux")

		reset_state()
	end)

	after_each(function()
		-- Restore original values
		vim.o.columns = saved_columns
		vim.o.lines = saved_lines
		vim.o.cmdheight = saved_cmdheight
		vim.o.laststatus = saved_laststatus
		vim.o.showtabline = saved_showtabline
	end)

	describe("create_root()", function()
		it("creates a root leaf node in pane_tree", function()
			setup_vim_mock(100, 50, 1, 2, 1)

			tmux.create_root()

			assert.is_not_nil(state.pane_tree)
			assert.are.equal("leaf", state.pane_tree.type)
			assert.are.equal(1, state.pane_tree.term_id)
		end)

		it("sets next_term_id to 2 after creation", function()
			setup_vim_mock(100, 50, 1, 2, 1)

			tmux.create_root()

			assert.are.equal(2, state.next_term_id)
		end)

		it("adds terminal to state.terminals", function()
			setup_vim_mock(100, 50, 1, 2, 1)

			local term = tmux.create_root()

			assert.are.equal(1, #state.terminals)
			assert.are.equal(term, state.terminals[1])
		end)

		it("sets state.visible to true", function()
			setup_vim_mock(100, 50, 1, 2, 1)

			tmux.create_root()

			assert.is_true(state.visible)
		end)

		it("sets last_focused_term_id", function()
			setup_vim_mock(100, 50, 1, 2, 1)

			tmux.create_root()

			assert.are.equal(1, state.last_focused_term_id)
		end)

		it("assigns term_id to terminal", function()
			setup_vim_mock(100, 50, 1, 2, 1)

			local term = tmux.create_root()

			assert.are.equal(1, term.term_id)
		end)
	end)

	describe("split()", function()
		before_each(function()
			setup_vim_mock(100, 50, 1, 2, 1)
			tmux.create_root()
		end)

		it("returns nil when pane_tree is nil", function()
			state.pane_tree = nil

			local result = tmux.split(1, "right")

			assert.is_nil(result)
		end)

		it("returns nil when term_id is not found", function()
			local result = tmux.split(999, "right")

			assert.is_nil(result)
		end)

		it("creates split node with correct type", function()
			tmux.split(1, "right")

			assert.are.equal("split", state.pane_tree.type)
		end)

		it("splits vertically for left/right directions", function()
			tmux.split(1, "right")

			assert.are.equal("v", state.pane_tree.dir)
		end)

		it("splits horizontally for up/down directions", function()
			tmux.split(1, "down")

			assert.are.equal("h", state.pane_tree.dir)
		end)

		it("places new pane first for up direction", function()
			tmux.split(1, "up")

			local children = state.pane_tree.children
			assert.are.equal(2, children[1].term_id)
			assert.are.equal(1, children[2].term_id)
		end)

		it("places new pane first for left direction", function()
			tmux.split(1, "left")

			local children = state.pane_tree.children
			assert.are.equal(2, children[1].term_id)
			assert.are.equal(1, children[2].term_id)
		end)

		it("places new pane second for down direction", function()
			tmux.split(1, "down")

			local children = state.pane_tree.children
			assert.are.equal(1, children[1].term_id)
			assert.are.equal(2, children[2].term_id)
		end)

		it("places new pane second for right direction", function()
			tmux.split(1, "right")

			local children = state.pane_tree.children
			assert.are.equal(1, children[1].term_id)
			assert.are.equal(2, children[2].term_id)
		end)

		it("sets split ratio to 0.5", function()
			tmux.split(1, "right")

			assert.are.equal(0.5, state.pane_tree.ratio)
		end)

		it("increments next_term_id", function()
			local before = state.next_term_id

			tmux.split(1, "right")

			assert.are.equal(before + 1, state.next_term_id)
		end)

		it("adds new terminal to state.terminals", function()
			local before_count = #state.terminals

			tmux.split(1, "right")

			assert.are.equal(before_count + 1, #state.terminals)
		end)

		it("assigns correct term_id to new terminal", function()
			local term = tmux.split(1, "right")

			assert.are.equal(2, term.term_id)
		end)

		it("handles multiple splits correctly", function()
			-- Split 1 -> creates 2
			tmux.split(1, "right")
			-- Split 2 -> creates 3
			tmux.split(2, "down")

			assert.are.equal(4, state.next_term_id)
			assert.are.equal(3, #state.terminals)
		end)

		it("restores maximized state before splitting", function()
			state.maximized_term_id = 1

			tmux.split(1, "right")

			assert.is_nil(state.maximized_term_id)
		end)
	end)

	describe("split direction helpers", function()
		before_each(function()
			setup_vim_mock(100, 50, 1, 2, 1)
			tmux.create_root()
		end)

		it("split_up creates horizontal split with new pane first", function()
			-- Mock vim.api.nvim_get_current_win to return the terminal window
			local orig_win = vim.api.nvim_get_current_win
			vim.api.nvim_get_current_win = function()
				return state.terminals[1].win
			end

			tmux.split_up()

			vim.api.nvim_get_current_win = orig_win
			assert.are.equal("h", state.pane_tree.dir)
			assert.are.equal(2, state.pane_tree.children[1].term_id)
		end)

		it("split_down creates horizontal split with new pane second", function()
			local orig_win = vim.api.nvim_get_current_win
			vim.api.nvim_get_current_win = function()
				return state.terminals[1].win
			end

			tmux.split_down()

			vim.api.nvim_get_current_win = orig_win
			assert.are.equal("h", state.pane_tree.dir)
			assert.are.equal(2, state.pane_tree.children[2].term_id)
		end)

		it("split_left creates vertical split with new pane first", function()
			local orig_win = vim.api.nvim_get_current_win
			vim.api.nvim_get_current_win = function()
				return state.terminals[1].win
			end

			tmux.split_left()

			vim.api.nvim_get_current_win = orig_win
			assert.are.equal("v", state.pane_tree.dir)
			assert.are.equal(2, state.pane_tree.children[1].term_id)
		end)

		it("split_right creates vertical split with new pane second", function()
			local orig_win = vim.api.nvim_get_current_win
			vim.api.nvim_get_current_win = function()
				return state.terminals[1].win
			end

			tmux.split_right()

			vim.api.nvim_get_current_win = orig_win
			assert.are.equal("v", state.pane_tree.dir)
			assert.are.equal(2, state.pane_tree.children[2].term_id)
		end)

		it("returns nil when current window is not a terminal", function()
			local orig_win = vim.api.nvim_get_current_win
			vim.api.nvim_get_current_win = function()
				return 99999 -- Non-terminal window
			end

			local result = tmux.split_right()

			vim.api.nvim_get_current_win = orig_win
			assert.is_nil(result)
		end)
	end)

	describe("remove()", function()
		before_each(function()
			setup_vim_mock(100, 50, 1, 2, 1)
		end)

		it("returns false when pane_tree is nil", function()
			local result = tmux.remove(1)

			assert.is_false(result)
		end)

		it("returns false when term_id is not found", function()
			tmux.create_root()

			local result = tmux.remove(999)

			assert.is_false(result)
		end)

		it("removes root pane and resets state", function()
			tmux.create_root()

			local result = tmux.remove(1)

			assert.is_true(result)
			assert.is_nil(state.pane_tree)
			assert.is_false(state.visible)
			assert.is_nil(state.maximized_term_id)
			assert.is_nil(state.last_focused_term_id)
		end)

		it("removes split pane and replaces with sibling", function()
			tmux.create_root()
			tmux.split(1, "right")

			local result = tmux.remove(2)

			assert.is_true(result)
			assert.are.equal("leaf", state.pane_tree.type)
			assert.are.equal(1, state.pane_tree.term_id)
		end)

		it("handles removing first child in split", function()
			tmux.create_root()
			tmux.split(1, "right")

			tmux.remove(1)

			assert.are.equal("leaf", state.pane_tree.type)
			assert.are.equal(2, state.pane_tree.term_id)
		end)

		it("handles nested splits correctly", function()
			tmux.create_root()
			tmux.split(1, "right")
			tmux.split(2, "down")

			-- Remove the middle terminal
			local result = tmux.remove(2)

			assert.is_true(result)
			assert.is_not_nil(state.pane_tree)
		end)

		it("updates last_focused_term_id when removing focused terminal", function()
			tmux.create_root()
			tmux.split(1, "right")
			state.last_focused_term_id = 2

			tmux.remove(2)

			assert.are.equal(1, state.last_focused_term_id)
		end)

		it("clears maximized_term_id when removing maximized terminal", function()
			tmux.create_root()
			tmux.split(1, "right")
			state.maximized_term_id = 2

			tmux.remove(2)

			assert.is_nil(state.maximized_term_id)
		end)
	end)

	describe("find_adjacent()", function()
		before_each(function()
			setup_vim_mock(100, 50, 1, 2, 1)
		end)

		it("returns nil when pane_tree is nil", function()
			local result = tmux.find_adjacent(1, "right")

			assert.is_nil(result)
		end)

		it("returns nil when term_id is not found", function()
			tmux.create_root()

			local result = tmux.find_adjacent(999, "right")

			assert.is_nil(result)
		end)

		it("returns nil when no adjacent pane in direction", function()
			tmux.create_root()

			local result = tmux.find_adjacent(1, "right")

			assert.is_nil(result)
		end)

		it("finds adjacent pane to the right", function()
			tmux.create_root()
			tmux.split(1, "right")

			local result = tmux.find_adjacent(1, "right")

			assert.are.equal(2, result)
		end)

		it("finds adjacent pane to the left", function()
			tmux.create_root()
			tmux.split(1, "right")

			local result = tmux.find_adjacent(2, "left")

			assert.are.equal(1, result)
		end)

		it("finds adjacent pane below", function()
			tmux.create_root()
			tmux.split(1, "down")

			local result = tmux.find_adjacent(1, "down")

			assert.are.equal(2, result)
		end)

		it("finds adjacent pane above", function()
			tmux.create_root()
			tmux.split(1, "down")

			local result = tmux.find_adjacent(2, "up")

			assert.are.equal(1, result)
		end)

		it("returns correct adjacent in complex layout", function()
			-- Create a 2x2 grid-like structure
			tmux.create_root()
			tmux.split(1, "right")
			tmux.split(1, "down")
			tmux.split(2, "down")

			-- Terminal 1 should find 3 below
			local result = tmux.find_adjacent(1, "down")
			assert.are.equal(3, result)

			-- Terminal 2 should find 4 below
			result = tmux.find_adjacent(2, "down")
			assert.are.equal(4, result)
		end)
	end)

	describe("get_win_config()", function()
		before_each(function()
			setup_vim_mock(100, 50, 1, 2, 1)
		end)

		it("returns nil when pane_tree is nil", function()
			local result = tmux.get_win_config(1)

			assert.is_nil(result)
		end)

		it("returns nil when term_id is not found", function()
			tmux.create_root()

			local result = tmux.get_win_config(999)

			assert.is_nil(result)
		end)

		it("returns correct config for root terminal", function()
			tmux.create_root()

			local cfg = tmux.get_win_config(1)

			assert.are.equal("editor", cfg.relative)
			assert.are.equal("NW", cfg.anchor)
			assert.are.equal("minimal", cfg.style)
			assert.are.equal("none", cfg.border)
			assert.are.equal(50, cfg.zindex)
		end)

		it("returns correct geometry for split panes", function()
			tmux.create_root()
			tmux.split(1, "right")

			local cfg1 = tmux.get_win_config(1)
			local cfg2 = tmux.get_win_config(2)

			-- Both should be valid configs
			assert.is_not_nil(cfg1)
			assert.is_not_nil(cfg2)

			-- Pane 2 should be to the right of pane 1
			assert.is_true(cfg2.col > cfg1.col)
		end)

		it("calculates correct dimensions for vertical split", function()
			setup_vim_mock(100, 50, 1, 2, 1)
			tmux.create_root()
			tmux.split(1, "right")

			local cfg1 = tmux.get_win_config(1)
			local cfg2 = tmux.get_win_config(2)

			-- editor_height = 50 - 1 (cmdheight) - 1 (laststatus) = 48
			-- Position "right" uses full editor height
			assert.are.equal(48, cfg1.height)
			assert.are.equal(48, cfg2.height)

			-- Widths should roughly split the space
			assert.are.equal(25, cfg1.width)
			assert.are.equal(25, cfg2.width)
		end)

		it("calculates correct dimensions for horizontal split", function()
			setup_vim_mock(100, 50, 1, 2, 1)
			tmux.create_root()
			tmux.split(1, "down")

			local cfg1 = tmux.get_win_config(1)
			local cfg2 = tmux.get_win_config(2)

			-- Both panes should have full width
			assert.are.equal(50, cfg1.width)
			assert.are.equal(50, cfg2.width)

			-- Heights should be split
			assert.are.equal(24, cfg1.height)
			assert.are.equal(24, cfg2.height)
		end)
	end)

	describe("reflow()", function()
		before_each(function()
			setup_vim_mock(100, 50, 1, 2, 1)
		end)

		it("does nothing when pane_tree is nil", function()
			-- Should not error
			tmux.reflow()

			assert.is_nil(state.pane_tree)
		end)

		it("does nothing when terminal is maximized", function()
			tmux.create_root()
			state.maximized_term_id = 1

			-- Should not error
			tmux.reflow()
		end)

		it("updates terminal configs after split", function()
			tmux.create_root()
			tmux.split(1, "right")

			-- Verify both terminals have been updated
			assert.is_not_nil(state.terminals[1].config)
			assert.is_not_nil(state.terminals[2].config)
		end)
	end)

	describe("toggle_maximize()", function()
		before_each(function()
			setup_vim_mock(100, 50, 1, 2, 1)
		end)

		it("does nothing when pane_tree is nil", function()
			-- Should not error
			tmux.toggle_maximize(1)
		end)

		it("sets maximized_term_id when maximizing", function()
			tmux.create_root()
			tmux.split(1, "right")

			tmux.toggle_maximize(1)

			assert.are.equal(1, state.maximized_term_id)
		end)

		it("clears maximized_term_id when restoring", function()
			tmux.create_root()
			tmux.split(1, "right")
			state.maximized_term_id = 1

			tmux.toggle_maximize(1)

			assert.is_nil(state.maximized_term_id)
		end)

		it("hides other terminals when maximizing", function()
			tmux.create_root()
			tmux.split(1, "right")

			tmux.toggle_maximize(1)

			-- Terminal 2 should be hidden (win is nil after hide)
			assert.is_nil(state.terminals[2].win)
		end)
	end)

	describe("update_border_highlight()", function()
		it("is a no-op function", function()
			-- Should not error when called
			tmux.update_border_highlight({}, "active")
			tmux.update_border_highlight(nil, nil)
		end)
	end)

	describe("focus_adjacent()", function()
		before_each(function()
			setup_vim_mock(100, 50, 1, 2, 1)
		end)

		it("returns false when pane_tree is nil", function()
			local result = tmux.focus_adjacent("right")
			assert.is_false(result)
		end)

		it("returns false when current window is not a terminal", function()
			tmux.create_root()
			-- Create non-terminal window
			local editor_buf = vim.api.nvim_create_buf(false, true)
			local editor_win = vim.api.nvim_open_win(editor_buf, true, {
				relative = "editor",
				row = 0,
				col = 0,
				width = 50,
				height = 25,
			})

			local result = tmux.focus_adjacent("right")

			vim.api.nvim_win_close(editor_win, true)
			vim.api.nvim_buf_delete(editor_buf, { force = true })
			assert.is_false(result)
		end)

		it("returns false when no adjacent pane in direction", function()
			tmux.create_root()
			local term_win = state.terminals[1].win
			vim.api.nvim_set_current_win(term_win)

			local result = tmux.focus_adjacent("right")

			assert.is_false(result)
		end)

		it("focuses adjacent pane to the right", function()
			tmux.create_root()
			tmux.split(1, "right")

			vim.api.nvim_set_current_win(state.terminals[1].win)

			local result = tmux.focus_adjacent("right")

			assert.is_true(result)
			assert.are.equal(state.terminals[2].win, vim.api.nvim_get_current_win())
		end)

		it("focuses adjacent pane to the left", function()
			tmux.create_root()
			tmux.split(1, "right")

			vim.api.nvim_set_current_win(state.terminals[2].win)

			local result = tmux.focus_adjacent("left")

			assert.is_true(result)
			assert.are.equal(state.terminals[1].win, vim.api.nvim_get_current_win())
		end)

		it("focuses adjacent pane above", function()
			tmux.create_root()
			tmux.split(1, "down")

			vim.api.nvim_set_current_win(state.terminals[2].win)

			local result = tmux.focus_adjacent("up")

			assert.is_true(result)
			assert.are.equal(state.terminals[1].win, vim.api.nvim_get_current_win())
		end)

		it("focuses adjacent pane below", function()
			tmux.create_root()
			tmux.split(1, "down")

			vim.api.nvim_set_current_win(state.terminals[1].win)

			local result = tmux.focus_adjacent("down")

			assert.is_true(result)
			assert.are.equal(state.terminals[2].win, vim.api.nvim_get_current_win())
		end)

		it("updates last_focused_term_id after focus", function()
			tmux.create_root()
			tmux.split(1, "right")
			state.last_focused_term_id = 1

			vim.api.nvim_set_current_win(state.terminals[1].win)

			tmux.focus_adjacent("right")

			assert.are.equal(2, state.last_focused_term_id)
		end)
	end)

	describe("focus direction helpers", function()
		before_each(function()
			setup_vim_mock(100, 50, 1, 2, 1)
			tmux.create_root()
		end)

		it("focus_up returns true when adjacent pane exists", function()
			tmux.split(1, "down")
			vim.api.nvim_set_current_win(state.terminals[2].win)

			local result = tmux.focus_up()

			assert.is_true(result)
		end)

		it("focus_down returns true when adjacent pane exists", function()
			tmux.split(1, "down")
			vim.api.nvim_set_current_win(state.terminals[1].win)

			local result = tmux.focus_down()

			assert.is_true(result)
		end)

		it("focus_left returns true when adjacent pane exists", function()
			tmux.split(1, "right")
			vim.api.nvim_set_current_win(state.terminals[2].win)

			local result = tmux.focus_left()

			assert.is_true(result)
		end)

		it("focus_right returns true when adjacent pane exists", function()
			tmux.split(1, "right")
			vim.api.nvim_set_current_win(state.terminals[1].win)

			local result = tmux.focus_right()

			assert.is_true(result)
		end)
	end)

	describe("edge cases", function()
		before_each(function()
			setup_vim_mock(100, 50, 1, 2, 1)
		end)

		it("handles rapid create/split/close cycles", function()
			-- Create root
			tmux.create_root()
			-- Split multiple times
			tmux.split(1, "right")
			tmux.split(2, "down")
			tmux.split(1, "down")
			-- Remove some
			tmux.remove(3)
			tmux.remove(2)

			-- Should still have valid tree (note: remove only updates tree structure,
			-- the actual terminal objects stay in state.terminals until buffer is wiped)
			assert.is_not_nil(state.pane_tree)
			assert.are.equal(4, #state.terminals)
		end)

		it("maintains tree structure through multiple splits", function()
			tmux.create_root()
			-- Create a complex tree
			tmux.split(1, "right")
			tmux.split(2, "down")
			tmux.split(1, "down")
			tmux.split(3, "right")

			-- Should have 5 terminals
			assert.are.equal(5, #state.terminals)
			assert.are.equal(6, state.next_term_id)
		end)
	end)
end)
