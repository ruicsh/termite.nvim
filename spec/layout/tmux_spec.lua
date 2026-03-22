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
			assert.are.equal("table", type(cfg.border))
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
		before_each(function()
			setup_vim_mock(100, 50, 1, 2, 1)
		end)

		it("returns early when window is nil or invalid", function()
			-- Should not error with nil window
			tmux.update_border_highlight({ win = nil }, "active")
		end)

		it("returns early when pane_tree is nil", function()
			-- Should not error when pane_tree is nil
			local term = { win = 1, term_id = 1 }
			vim.api.nvim_win_is_valid = function(_winid)
				return true
			end
			tmux.update_border_highlight(term, "active")
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

	describe("build_pane_border() T-junction corners", function()
		local constants

		before_each(function()
			setup_vim_mock(100, 50, 1, 2, 1)
			-- Note: config is already set to position="right" by parent before_each
			-- Tests that need different position will set it themselves
			constants = require("termite.constants")
			tmux.create_root()
		end)

		it("uses horizontal_down for top-right corner when pane above spans wider", function()
			-- Create: Term1 on top (full width), Term2 below left, Term3 below right
			-- First split root horizontally to create top/bottom
			tmux.split(1, "down") -- Now: Term1 (top), Term2 (bottom)
			-- Split Term2 vertically to create left/right
			tmux.split(2, "right") -- Now: Term1 (top), Term2 (bottom-left), Term3 (bottom-right)

			-- Get geometries
			local geoms = tmux._test.get_leaf_geometries(state.pane_tree, tmux._test.get_editor_rect())

			-- Build border for Term2 (bottom-left pane)
			local root_rect = tmux._test.get_editor_rect()
			local border = tmux._test.build_pane_border(geoms[2], root_rect, "right", geoms)

			-- Term2's top-right corner should be horizontal_down (┬), not cross (┼)
			-- because Term1 spans above it and continues past its right edge
			assert.are.equal("┬", border[constants.BORDER_TOP_RIGHT])
		end)

		it("uses horizontal_down for top-left corner when pane above spans wider", function()
			-- Create: Term1 on top (full width), Term3 below left, Term2 below right
			tmux.split(1, "down") -- Term1 (top), Term2 (bottom)
			tmux.split(2, "left") -- Split Term2: Term3 (bottom-left), Term2 (bottom-right)

			local geoms = tmux._test.get_leaf_geometries(state.pane_tree, tmux._test.get_editor_rect())
			local root_rect = tmux._test.get_editor_rect()
			local border = tmux._test.build_pane_border(geoms[2], root_rect, "right", geoms)

			-- Term2's top-left corner should be horizontal_down (┬), not cross (┼)
			-- because Term1 spans above it and continues past its left edge
			assert.are.equal("┬", border[constants.BORDER_TOP_LEFT])
		end)

		it("uses horizontal_up for bottom-right corner when pane below spans wider", function()
			-- Create layout: Term1 (top-left), Term2 (top-right), Term3 below both
			tmux.split(1, "down") -- Term1 (top), Term3 (bottom)
			tmux.split(1, "right") -- Split Term1: Term1 (top-left), Term2 (top-right)

			local geoms = tmux._test.get_leaf_geometries(state.pane_tree, tmux._test.get_editor_rect())
			local root_rect = tmux._test.get_editor_rect()
			local border = tmux._test.build_pane_border(geoms[1], root_rect, "right", geoms)

			-- Term1's bottom-right corner should be horizontal_up (┴), not cross (┼)
			-- because Term3 spans below it and continues past its right edge
			assert.are.equal("┴", border[constants.BORDER_BOTTOM_RIGHT])
		end)

		it("uses horizontal_up for bottom-left corner when pane below spans wider", function()
			-- Create layout: Term1 (top-right), Term2 (top-left), Term3 below both
			tmux.split(1, "down") -- Term1 (top), Term3 (bottom)
			tmux.split(1, "left") -- Split Term1: Term2 (top-left), Term1 (top-right)

			local geoms = tmux._test.get_leaf_geometries(state.pane_tree, tmux._test.get_editor_rect())
			local root_rect = tmux._test.get_editor_rect()
			local border = tmux._test.build_pane_border(geoms[1], root_rect, "right", geoms)

			-- Term1's bottom-left corner should be horizontal_up (┴), not cross (┼)
			assert.are.equal("┴", border[constants.BORDER_BOTTOM_LEFT])
		end)

		it("uses cross for inner corners when no spanning neighbor", function()
			-- Simple 2x2 grid where no pane spans past corners
			tmux.split(1, "right") -- Term1 (left), Term2 (right)
			tmux.split(1, "down") -- Split Term1: Term1 (top-left), Term3 (bottom-left)
			tmux.split(2, "down") -- Split Term2: Term2 (top-right), Term4 (bottom-right)

			local geoms = tmux._test.get_leaf_geometries(state.pane_tree, tmux._test.get_editor_rect())
			local root_rect = tmux._test.get_editor_rect()
			local border = tmux._test.build_pane_border(geoms[1], root_rect, "right", geoms)

			-- Term1's corners: top-left is outer, top-right borders Term2
			-- No T-junctions in this layout since nothing spans full width
			assert.are.equal("┼", border[constants.BORDER_BOTTOM_RIGHT])
		end)

		it("handles T-junction when pane above spans wider", function()
			-- Layout: Term1 spans full width above, Term2 is narrower below
			-- Use position="bottom" to avoid outer edge interference
			config.setup({ layout = "tmux", position = "bottom", width = 0.5, height = 0.5 })
			state.pane_tree = nil
			state.terminals = {}
			state.next_term_id = 1
			tmux.create_root()

			-- Create: Term1 on top (full width), Term2 below left, Term3 below right
			tmux.split(1, "down") -- Term1 (top), Term2 (bottom)
			tmux.split(2, "right") -- Split bottom: Term2 (bottom-left), Term3 (bottom-right)

			local geoms = tmux._test.get_leaf_geometries(state.pane_tree, tmux._test.get_editor_rect())
			local root_rect = tmux._test.get_editor_rect()

			-- Term2 has Term1 spanning above it (full width)
			-- Term1: col=0, width=100 (spans full width)
			-- Term2: col=0, width=50
			-- So Term1 extends past Term2's right edge -> T-junction
			local border2 = tmux._test.build_pane_border(geoms[2], root_rect, "bottom", geoms)
			assert.are.equal("┬", border2[constants.BORDER_TOP_RIGHT])

			-- Term3 also has Term1 spanning above it
			-- Term3: col=50, width=50
			-- Term1 extends past Term3's left edge (col=0 < col=50) -> T-junction
			local border3 = tmux._test.build_pane_border(geoms[3], root_rect, "bottom", geoms)
			assert.are.equal("┬", border3[constants.BORDER_TOP_LEFT])
		end)

		it("handles T-junction when pane below spans wider", function()
			-- Layout: Term1 is narrower on top, Term2 spans full width below
			config.setup({ layout = "tmux", position = "bottom", width = 0.5, height = 0.5 })
			state.pane_tree = nil
			state.terminals = {}
			state.next_term_id = 1
			tmux.create_root()

			-- Create: Term1 top left, Term2 top right, Term3 below (full width)
			tmux.split(1, "down") -- Term1 (top), Term3 (bottom)
			tmux.split(1, "right") -- Split top: Term1 (top-left), Term2 (top-right)

			local geoms = tmux._test.get_leaf_geometries(state.pane_tree, tmux._test.get_editor_rect())
			local root_rect = tmux._test.get_editor_rect()

			-- Term1 has Term3 spanning below it (full width)
			-- Term1: col=0, width=50 -> right edge at 50
			-- Term3: col=0, width=100 -> extends to 100
			-- So Term3 extends past Term1's right edge -> T-junction (┴)
			local border1 = tmux._test.build_pane_border(geoms[1], root_rect, "bottom", geoms)
			assert.are.equal("┴", border1[constants.BORDER_BOTTOM_RIGHT])

			-- Term3 (top-right) also has Term2 (bottom) spanning below it
			-- Term3: col=50, width=50 -> left edge at 50
			-- Term2: col=0 -> extends left of Term3's left edge -> T-junction (┴)
			local border3 = tmux._test.build_pane_border(geoms[3], root_rect, "bottom", geoms)
			assert.are.equal("┴", border3[constants.BORDER_BOTTOM_LEFT])
		end)

		it("correctly identifies cross at intersection of four equal panes", function()
			-- 2x2 grid - all corners at the center should be cross
			-- Note: With position="right", outer_left is set for panes at root_rect.col
			-- So we test with position="bottom" to get cleaner inner corner detection
			config.setup({ layout = "tmux", position = "bottom", width = 0.5, height = 0.5 })
			state.pane_tree = nil
			state.terminals = {}
			state.next_term_id = 1
			tmux.create_root()

			tmux.split(1, "right") -- Term1 (left), Term2 (right)
			tmux.split(1, "down") -- Split Term1: Term1 (top-left), Term3 (bottom-left)
			tmux.split(2, "down") -- Split Term2: Term2 (top-right), Term4 (bottom-right)

			local geoms = tmux._test.get_leaf_geometries(state.pane_tree, tmux._test.get_editor_rect())
			local root_rect = tmux._test.get_editor_rect()

			local border1 = tmux._test.build_pane_border(geoms[1], root_rect, "bottom", geoms)
			local border2 = tmux._test.build_pane_border(geoms[2], root_rect, "bottom", geoms)
			local border3 = tmux._test.build_pane_border(geoms[3], root_rect, "bottom", geoms)
			local border4 = tmux._test.build_pane_border(geoms[4], root_rect, "bottom", geoms)

			-- All corners at the center intersection should be cross
			assert.are.equal("┼", border1[constants.BORDER_BOTTOM_RIGHT])
			assert.are.equal("┼", border2[constants.BORDER_BOTTOM_LEFT])
			assert.are.equal("┼", border3[constants.BORDER_TOP_RIGHT])
			assert.are.equal("┼", border4[constants.BORDER_TOP_LEFT])
		end)

		it("handles single pane with no neighbors", function()
			-- Just the root pane - no splits
			local geoms = tmux._test.get_leaf_geometries(state.pane_tree, tmux._test.get_editor_rect())
			local root_rect = tmux._test.get_editor_rect()
			local border = tmux._test.build_pane_border(geoms[1], root_rect, "right", geoms)

			-- Single pane should have no corners set (only outer edges)
			assert.are.equal("", border[constants.BORDER_TOP_LEFT])
			assert.are.equal("", border[constants.BORDER_TOP_RIGHT])
			assert.are.equal("", border[constants.BORDER_BOTTOM_LEFT])
			assert.are.equal("", border[constants.BORDER_BOTTOM_RIGHT])
		end)

		it("handles two vertical panes with no T-junctions", function()
			-- Simple vertical split - no horizontal edges means no corners
			tmux.split(1, "right") -- Term1 (left), Term2 (right)

			local geoms = tmux._test.get_leaf_geometries(state.pane_tree, tmux._test.get_editor_rect())
			local root_rect = tmux._test.get_editor_rect()

			local border1 = tmux._test.build_pane_border(geoms[1], root_rect, "right", geoms)
			local border2 = tmux._test.build_pane_border(geoms[2], root_rect, "right", geoms)

			-- No corners for vertical-only split
			assert.are.equal("", border1[constants.BORDER_TOP_LEFT])
			assert.are.equal("", border1[constants.BORDER_TOP_RIGHT])
			assert.are.equal("", border2[constants.BORDER_TOP_LEFT])
			assert.are.equal("", border2[constants.BORDER_TOP_RIGHT])
		end)

		it("handles two horizontal panes with no vertical edges", function()
			-- Simple horizontal split - with position="bottom", outer_top is set
			-- so top edge only, no vertical edges means no corners
			config.setup({ layout = "tmux", position = "bottom", width = 0.5, height = 0.5 })
			state.pane_tree = nil
			state.terminals = {}
			state.next_term_id = 1
			tmux.create_root()

			tmux.split(1, "down") -- Term1 (top), Term2 (bottom)

			local geoms = tmux._test.get_leaf_geometries(state.pane_tree, tmux._test.get_editor_rect())
			local root_rect = tmux._test.get_editor_rect()

			local border1 = tmux._test.build_pane_border(geoms[1], root_rect, "bottom", geoms)
			local border2 = tmux._test.build_pane_border(geoms[2], root_rect, "bottom", geoms)

			-- Top pane: no left/right edges, only bottom edge
			assert.are.equal("", border1[constants.BORDER_TOP_LEFT])
			assert.are.equal("", border1[constants.BORDER_TOP_RIGHT])
			assert.are.equal("", border1[constants.BORDER_BOTTOM_LEFT])
			assert.are.equal("", border1[constants.BORDER_BOTTOM_RIGHT])

			-- Bottom pane: outer_top edge only
			assert.are.equal("", border2[constants.BORDER_TOP_LEFT])
			assert.are.equal("", border2[constants.BORDER_TOP_RIGHT])
			assert.are.equal("", border2[constants.BORDER_BOTTOM_LEFT])
			assert.are.equal("", border2[constants.BORDER_BOTTOM_RIGHT])
		end)
	end)
end)
