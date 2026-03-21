-- termite.nvim
-- Tests for init.lua - Public API and terminal lifecycle

describe("init module", function()
	local termite
	local config
	local state

	before_each(function()
		-- Reset all modules for fresh state
		package.loaded["termite.config"] = nil
		package.loaded["termite.state"] = nil
		package.loaded["termite.terminal"] = nil
		package.loaded["termite.layout"] = nil
		package.loaded["termite.layout.tmux"] = nil
		package.loaded["termite.layout.stack"] = nil
		package.loaded["termite.highlights"] = nil
		package.loaded["termite.init"] = nil

		config = require("termite.config")
		state = require("termite.state")
		termite = require("termite.init")

		config.setup({})

		-- Create a non-terminal buffer to serve as editor window
		local editor_buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_set_current_buf(editor_buf)
		state.last_editor_winnr = vim.api.nvim_get_current_win()
	end)

	after_each(function()
		-- Clean up any remaining terminal windows and buffers
		for _, term in ipairs(state.terminals) do
			if term.win and vim.api.nvim_win_is_valid(term.win) then
				vim.api.nvim_win_close(term.win, true)
			end
			if term.buf and vim.api.nvim_buf_is_valid(term.buf) then
				vim.api.nvim_buf_delete(term.buf, { force = true })
			end
		end
		state.terminals = {}
		state.visible = false
		state.pane_tree = nil
	end)

	describe("focus_next()", function()
		it("does nothing when no terminals exist", function()
			-- Should not error
			termite.focus_next()
			assert.are.equal(0, #state.terminals)
		end)

		it("cycles to next terminal in stack", function()
			termite.create()
			termite.create()

			local first_win = state.terminals[1].win
			vim.api.nvim_set_current_win(first_win)

			termite.focus_next()

			assert.are.equal(state.terminals[2].win, vim.api.nvim_get_current_win())
		end)

		it("wraps around from last to first terminal", function()
			termite.create()
			termite.create()
			termite.create()

			vim.api.nvim_set_current_win(state.terminals[3].win)

			termite.focus_next()

			assert.are.equal(state.terminals[1].win, vim.api.nvim_get_current_win())
		end)

		it("does nothing when focus is on editor window", function()
			termite.create()
			termite.create()

			-- Focus editor window
			vim.api.nvim_set_current_win(state.last_editor_winnr)

			local editor_win = vim.api.nvim_get_current_win()
			termite.focus_next()

			assert.are.equal(editor_win, vim.api.nvim_get_current_win())
		end)

		it("does nothing when terminal is maximized", function()
			termite.create()
			termite.create()

			vim.api.nvim_set_current_win(state.terminals[1].win)
			state.maximized_idx = 1

			termite.focus_next()

			assert.are.equal(state.terminals[1].win, vim.api.nvim_get_current_win())
		end)
	end)

	describe("focus_prev()", function()
		it("does nothing when no terminals exist", function()
			-- Should not error
			termite.focus_prev()
			assert.are.equal(0, #state.terminals)
		end)

		it("cycles to previous terminal in stack", function()
			termite.create()
			termite.create()

			vim.api.nvim_set_current_win(state.terminals[2].win)

			termite.focus_prev()

			assert.are.equal(state.terminals[1].win, vim.api.nvim_get_current_win())
		end)

		it("wraps around from first to last terminal", function()
			termite.create()
			termite.create()
			termite.create()

			vim.api.nvim_set_current_win(state.terminals[1].win)

			termite.focus_prev()

			assert.are.equal(state.terminals[3].win, vim.api.nvim_get_current_win())
		end)

		it("does nothing when focus is on editor window", function()
			termite.create()
			termite.create()

			-- Focus editor window
			vim.api.nvim_set_current_win(state.last_editor_winnr)

			local editor_win = vim.api.nvim_get_current_win()
			termite.focus_prev()

			assert.are.equal(editor_win, vim.api.nvim_get_current_win())
		end)

		it("does nothing when terminal is maximized", function()
			termite.create()
			termite.create()

			vim.api.nvim_set_current_win(state.terminals[1].win)
			state.maximized_idx = 1

			termite.focus_prev()

			assert.are.equal(state.terminals[1].win, vim.api.nvim_get_current_win())
		end)
	end)

	describe("remove_terminal() - close → focus sibling behavior", function()
		it("focuses sibling when removing a terminal", function()
			termite.create()
			termite.create()

			local sibling_win = state.terminals[1].win
			local term_to_remove = state.terminals[2]

			vim.api.nvim_set_current_win(term_to_remove.win)

			termite.remove_terminal(term_to_remove)

			assert.are.equal(sibling_win, vim.api.nvim_get_current_win())
			assert.are.equal(1, #state.terminals)
		end)

		it("focuses previous terminal when removing with fallback", function()
			termite.create()
			termite.create()
			termite.create()

			-- Focus on terminal 2 and remove it
			vim.api.nvim_set_current_win(state.terminals[2].win)

			termite.remove_terminal(state.terminals[2])

			-- Should focus terminal 1 (previous index)
			assert.are.equal(state.terminals[1].win, vim.api.nvim_get_current_win())
		end)

		it("focuses editor window when all terminals closed", function()
			termite.create()

			local term = state.terminals[1]
			vim.api.nvim_set_current_win(term.win)

			termite.remove_terminal(term)

			assert.are.equal(state.last_editor_winnr, vim.api.nvim_get_current_win())
			assert.are.equal(0, #state.terminals)
			assert.is_false(state.visible)
		end)

		it("clears pane_tree when last terminal removed", function()
			termite.create()

			local term = state.terminals[1]
			termite.remove_terminal(term)

			assert.is_nil(state.pane_tree)
		end)

		it("clears maximized_idx when removing maximized terminal", function()
			termite.create()
			termite.create()

			state.maximized_idx = 2

			termite.remove_terminal(state.terminals[2])

			assert.is_nil(state.maximized_idx)
		end)
	end)

	describe("remove_terminal() edge cases", function()
		it("adjusts maximized_idx when earlier terminal is removed", function()
			termite.create()
			termite.create()
			termite.create()

			state.maximized_idx = 3

			termite.remove_terminal(state.terminals[1])

			assert.are.equal(2, state.maximized_idx)
		end)

		it("does not adjust maximized_idx when later terminal is removed", function()
			termite.create()
			termite.create()
			termite.create()

			state.maximized_idx = 1

			termite.remove_terminal(state.terminals[3])

			assert.are.equal(1, state.maximized_idx)
		end)

		it("focuses previous terminal when removing middle terminal", function()
			termite.create()
			termite.create()
			termite.create()

			vim.api.nvim_set_current_win(state.terminals[2].win)

			termite.remove_terminal(state.terminals[2])

			assert.are.equal(state.terminals[1].win, vim.api.nvim_get_current_win())
		end)

		it("restores maximized siblings when maximized terminal removed", function()
			termite.create()
			termite.create()
			termite.create()

			vim.api.nvim_set_current_win(state.terminals[2].win)
			state.maximized_idx = 2
			-- Hide other terminals to simulate maximized state
			vim.api.nvim_win_close(state.terminals[1].win, true)
			state.terminals[1].win = nil
			vim.api.nvim_win_close(state.terminals[3].win, true)
			state.terminals[3].win = nil

			termite.remove_terminal(state.terminals[2])

			assert.is_nil(state.maximized_idx)
		end)
	end)

	describe("close_current()", function()
		it("closes the currently focused terminal", function()
			termite.create()
			termite.create()

			vim.api.nvim_set_current_win(state.terminals[1].win)

			termite.close_current()

			assert.are.equal(1, #state.terminals)
		end)

		it("focuses next terminal after closing", function()
			termite.create()
			termite.create()
			termite.create()

			vim.api.nvim_set_current_win(state.terminals[1].win)

			termite.close_current()

			assert.are.equal(state.terminals[1].win, vim.api.nvim_get_current_win())
		end)

		it("does nothing when focus is not on a terminal", function()
			termite.create()
			termite.create()

			-- Focus editor window
			vim.api.nvim_set_current_win(state.last_editor_winnr)

			local initial_count = #state.terminals
			termite.close_current()

			assert.are.equal(initial_count, #state.terminals)
		end)

		it("focuses editor when all terminals closed", function()
			termite.create()

			vim.api.nvim_set_current_win(state.terminals[1].win)

			termite.close_current()

			assert.are.equal(state.last_editor_winnr, vim.api.nvim_get_current_win())
		end)
	end)
end)

-- vim: foldmethod=marker:foldmarker={{{,}}}:foldlevel=0
