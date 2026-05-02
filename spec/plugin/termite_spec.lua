-- termite.nvim
-- Plugin autocmds and user commands tests

describe("plugin/termite", function()
	local state
	local config
	local highlights

	before_each(function()
		-- Reset all modules for fresh state
		package.loaded["termite.config"] = nil
		package.loaded["termite.state"] = nil
		package.loaded["termite.terminal"] = nil
		package.loaded["termite.layout"] = nil
		package.loaded["termite.highlights"] = nil
		package.loaded["termite.init"] = nil

		config = require("termite.config")
		highlights = require("termite.highlights")
		state = require("termite.state")
		-- Load termite.init for side effects (sets up commands)
		require("termite.init")

		config.setup({})

		-- Load the plugin file which creates commands and autocmds
		vim.cmd("source " .. vim.fn.getcwd() .. "/plugin/termite.lua")

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
	end)

	describe(":Termite command", function()
		it("exists and is callable", function()
			local commands = vim.api.nvim_get_commands({})
			assert.is_not_nil(commands.Termite)
		end)

		it("command is executable with no arguments", function()
			-- Command should not error when executed with no arguments
			-- (In headless test mode, actual terminal creation may not work)
			local success, err = pcall(vim.cmd, "Termite")
			assert.is_true(success, "Command should not error: " .. tostring(err))
		end)

		it("warns on unknown subcommand", function()
			local notified = false
			local original_notify = vim.notify
			vim.notify = function(msg, _level)
				if msg:match("unknown command") then
					notified = true
				end
			end

			vim.cmd("Termite unknown")

			assert.is_true(notified)

			-- Restore original notify
			vim.notify = original_notify
		end)

		it("provides command completion", function()
			local termite_cmd = vim.api.nvim_get_commands({}).Termite
			assert.is_not_nil(termite_cmd.complete)
		end)
	end)

	describe("autocmds", function()
		it("VimResized autocmd is registered", function()
			local autocmds = vim.api.nvim_get_autocmds({ group = "termite/plugin", event = "VimResized" })
			assert.is_true(#autocmds > 0)
		end)

		it("WinEnter autocmd is registered", function()
			local autocmds = vim.api.nvim_get_autocmds({ group = "termite/plugin", event = "WinEnter" })
			assert.is_true(#autocmds > 0)
		end)

		describe("WinEnter border highlight fix", function()
			local function spy_on_build_highlighted_border()
				local layout_stack = require("termite.layout.stack")
				local original = layout_stack.build_highlighted_border
				local captured = {}
				layout_stack.build_highlighted_border = function(border, position, hl_type)
					table.insert(captured, hl_type)
					return original(border, position, hl_type)
				end
				return captured, function()
					layout_stack.build_highlighted_border = original
				end
			end

			local function make_editor_win()
				local buf = vim.api.nvim_create_buf(false, true)
				return vim.api.nvim_open_win(buf, true, {
					relative = "editor",
					width = 10,
					height = 10,
					row = 0,
					col = 0,
				})
			end

			it("passes 'single' for the only terminal", function()
				highlights.setup()
				local terminal = require("termite.terminal")
				local editor_win = make_editor_win()
				local term = terminal.create()
				assert.are.equal(1, #state.terminals)

				-- Created terminal auto-enters. Switch to editor first to leave it,
				-- so WinEnter fires again when we go back.
				vim.api.nvim_set_current_win(editor_win)

				local captured, restore = spy_on_build_highlighted_border()

				vim.api.nvim_set_current_win(term.win)

				restore()
				assert.are.equal(1, #captured)
				assert.are.equal("single", captured[1])
				vim.api.nvim_win_close(editor_win, true)
			end)

			it("passes 'active' and 'inactive' when switching between two terminals", function()
				highlights.setup()
				local terminal = require("termite.terminal")
				local editor_win = make_editor_win()
				local term1 = terminal.create()
				terminal.create()
				assert.are.equal(2, #state.terminals)

				vim.api.nvim_set_current_win(editor_win)

				local captured, restore = spy_on_build_highlighted_border()

				vim.api.nvim_set_current_win(term1.win)

				restore()
				assert.are.equal(2, #captured)
				assert.are.equal("active", captured[1], "first terminal should be active")
				assert.are.equal("inactive", captured[2], "second terminal should be inactive")
				vim.api.nvim_win_close(editor_win, true)
			end)

			it("does not call build_highlighted_border when entering a non-termite window", function()
				highlights.setup()
				local terminal = require("termite.terminal")
				local editor_win = make_editor_win()
				terminal.create()
				terminal.create()
				assert.are.equal(2, #state.terminals)

				-- Create a non-termite window to switch to
				local other_buf = vim.api.nvim_create_buf(false, true)
				local other_win = vim.api.nvim_open_win(other_buf, true, {
					relative = "editor",
					width = 10,
					height = 10,
					row = 0,
					col = 0,
				})

				vim.api.nvim_set_current_win(editor_win)

				local captured, restore = spy_on_build_highlighted_border()

				vim.api.nvim_set_current_win(other_win)

				restore()
				assert.are.equal(0, #captured, "should not update borders for non-termite windows")
				vim.api.nvim_win_close(other_win, true)
				vim.api.nvim_win_close(editor_win, true)
			end)
		end)
	end)
end)

-- vim: foldmethod=marker:foldmarker={{{,}}}:foldlevel=0
