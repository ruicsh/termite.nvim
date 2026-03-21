-- termite.nvim
-- State management tests

describe("state management", function()
	local termite
	local state

	before_each(function()
		-- Reset all termite modules to get fresh state
		package.loaded["termite.config"] = nil
		package.loaded["termite.state"] = nil
		package.loaded["termite.terminal"] = nil
		package.loaded["termite.layout"] = nil
		package.loaded["termite.highlights"] = nil
		package.loaded["termite.init"] = nil

		termite = require("termite.init")
		state = require("termite.state")

		-- Setup with default config
		termite.setup()

		-- Create a non-terminal buffer to serve as editor window
		local editor_buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_set_current_buf(editor_buf)
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
		state.maximized_idx = nil
		state.last_focused_idx = nil
		state.next_count = 1
	end)

	describe("initial state", function()
		it("has correct default values", function()
			assert.are.same({}, state.terminals)
			assert.are.equal(false, state.visible)
			assert.are.equal(nil, state.maximized_idx)
			assert.are.equal(nil, state.last_editor_winnr)
			assert.are.equal(nil, state.last_focused_idx)
			assert.are.equal(1, state.next_count)
		end)
	end)

	describe("terminal creation", function()
		it("increments next_count on each create", function()
			assert.are.equal(1, state.next_count)

			termite.create()
			assert.are.equal(2, state.next_count)

			termite.create()
			assert.are.equal(3, state.next_count)
		end)

		it("adds terminal to terminals list", function()
			assert.are.equal(0, #state.terminals)

			termite.create()
			assert.are.equal(1, #state.terminals)
			assert.is_not_nil(state.terminals[1])
			assert.is_not_nil(state.terminals[1].buf)
			assert.is_not_nil(state.terminals[1].win)
		end)

		it("sets visible to true after creation", function()
			assert.are.equal(false, state.visible)

			termite.create()
			assert.are.equal(true, state.visible)
		end)

		it("sets last_focused_idx to new terminal", function()
			assert.are.equal(nil, state.last_focused_idx)

			termite.create()
			assert.are.equal(1, state.last_focused_idx)

			termite.create()
			assert.are.equal(2, state.last_focused_idx)
		end)
	end)

	describe("terminal removal", function()
		it("removes terminal from list on close_current", function()
			termite.create()
			termite.create()
			assert.are.equal(2, #state.terminals)

			termite.close_current()
			assert.are.equal(1, #state.terminals)
		end)

		it("sets visible to false when last terminal closed", function()
			termite.create()
			assert.are.equal(true, state.visible)

			termite.close_current()
			assert.are.equal(false, state.visible)
		end)

		it("preserves last_focused_idx when closing terminal", function()
			termite.create()
			termite.create()
			termite.create()
			assert.are.equal(3, state.last_focused_idx)

			-- close_current focuses the window but does not update last_focused_idx
			termite.close_current()
			assert.are.equal(3, state.last_focused_idx)
		end)

		it("clears maximized_idx when closing the maximized terminal itself", function()
			termite.create()
			termite.create()
			termite.create()

			-- Maximize the third terminal
			termite.toggle_maximize()
			assert.are.equal(3, state.maximized_idx)

			-- Close the maximized terminal (terminal 3)
			termite.close_current()

			-- maximized_idx should be cleared since the maximized terminal was closed
			assert.are.equal(nil, state.maximized_idx)
			assert.are.equal(2, #state.terminals)
		end)
	end)

	describe("toggle visibility", function()
		it("toggles visible state", function()
			termite.create()
			assert.are.equal(true, state.visible)

			termite.toggle()
			assert.are.equal(false, state.visible)

			termite.toggle()
			assert.are.equal(true, state.visible)
		end)

		it("clears maximized_idx on hide", function()
			termite.create()
			termite.create()
			termite.toggle_maximize()
			assert.are.equal(2, state.maximized_idx)

			termite.toggle()
			assert.are.equal(nil, state.maximized_idx)
		end)

		it("saves last_editor_winnr when toggling from editor", function()
			local editor_win = vim.api.nvim_get_current_win()
			assert.are.equal(nil, state.last_editor_winnr)

			-- toggle() saves editor window before showing terminals
			termite.toggle()
			assert.are.equal(editor_win, state.last_editor_winnr)
		end)
	end)

	describe("focus management", function()
		it("updates last_focused_idx on focus_next", function()
			termite.create()
			termite.create()
			termite.create()
			assert.are.equal(3, state.last_focused_idx)

			termite.focus_next()
			assert.are.equal(1, state.last_focused_idx)

			termite.focus_next()
			assert.are.equal(2, state.last_focused_idx)
		end)

		it("updates last_focused_idx on focus_prev", function()
			termite.create()
			termite.create()
			termite.create()
			assert.are.equal(3, state.last_focused_idx)

			termite.focus_prev()
			assert.are.equal(2, state.last_focused_idx)

			termite.focus_prev()
			assert.are.equal(1, state.last_focused_idx)
		end)

		it("preserves last_focused_idx across hide/show", function()
			termite.create()
			termite.create()
			assert.are.equal(2, state.last_focused_idx)

			termite.toggle()
			assert.are.equal(2, state.last_focused_idx)

			termite.toggle()
			assert.are.equal(2, state.last_focused_idx)
		end)
	end)

	describe("maximize state", function()
		it("sets maximized_idx when maximizing", function()
			termite.create()
			assert.are.equal(nil, state.maximized_idx)

			termite.toggle_maximize()
			assert.are.equal(1, state.maximized_idx)
		end)

		it("clears maximized_idx when restoring", function()
			termite.create()
			termite.toggle_maximize()
			assert.are.equal(1, state.maximized_idx)

			termite.toggle_maximize()
			assert.are.equal(nil, state.maximized_idx)
		end)

		it("clears maximized_idx when creating new terminal", function()
			termite.create()
			termite.create()
			termite.toggle_maximize()
			assert.are.equal(2, state.maximized_idx)

			termite.create()
			assert.are.equal(nil, state.maximized_idx)
		end)

		it("prevents focus_next when maximized", function()
			termite.create()
			termite.create()
			termite.toggle_maximize()

			local original_idx = state.last_focused_idx
			termite.focus_next()
			assert.are.equal(original_idx, state.last_focused_idx)
		end)

		it("prevents focus_prev when maximized", function()
			termite.create()
			termite.create()
			termite.toggle_maximize()

			local original_idx = state.last_focused_idx
			termite.focus_prev()
			assert.are.equal(original_idx, state.last_focused_idx)
		end)
	end)

	describe("edge cases", function()
		it("handles closing the maximized terminal", function()
			termite.create()
			termite.create()
			termite.create()

			termite.toggle_maximize()
			assert.are.equal(3, state.maximized_idx)

			termite.close_current()
			assert.are.equal(nil, state.maximized_idx)
			assert.are.equal(2, #state.terminals)
		end)

		it("handles rapid create/close cycles", function()
			termite.create()
			termite.create()
			termite.close_current()
			termite.create()
			termite.create()
			termite.close_current()
			termite.close_current()

			assert.are.equal(1, #state.terminals)
			assert.are.equal(true, state.visible)
		end)

		it("resets state after all terminals closed", function()
			termite.create()
			termite.create()
			termite.toggle_maximize()

			termite.close_current()
			termite.close_current()

			assert.are.equal(0, #state.terminals)
			assert.are.equal(false, state.visible)
			assert.are.equal(nil, state.maximized_idx)
		end)

		it("maintains terminal count integrity through operations", function()
			termite.create()
			termite.create()
			termite.create()

			local original_count = state.next_count
			assert.are.equal(4, original_count)

			termite.close_current()
			termite.create()

			-- next_count should continue incrementing, not reset
			assert.are.equal(5, state.next_count)
		end)
	end)
end)

-- vim: foldmethod=marker:foldmarker={{{,}}}:foldlevel=0
