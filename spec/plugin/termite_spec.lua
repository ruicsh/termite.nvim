-- termite.nvim
-- Plugin autocmds and user commands tests

describe("plugin/termite", function()
	local state
	local config

	before_each(function()
		-- Reset all modules for fresh state
		package.loaded["termite.config"] = nil
		package.loaded["termite.state"] = nil
		package.loaded["termite.terminal"] = nil
		package.loaded["termite.layout"] = nil
		package.loaded["termite.highlights"] = nil
		package.loaded["termite.init"] = nil

		config = require("termite.config")
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
	end)
end)

-- vim: foldmethod=marker:foldmarker={{{,}}}:foldlevel=0
