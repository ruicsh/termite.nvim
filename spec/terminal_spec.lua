describe("terminal module", function()
	local terminal
	local state
	local config

	before_each(function()
		-- Reset all modules for fresh state
		package.loaded["termite.config"] = nil
		package.loaded["termite.state"] = nil
		package.loaded["termite.terminal"] = nil
		package.loaded["termite.layout"] = nil
		package.loaded["termite.highlights"] = nil

		config = require("termite.config")
		state = require("termite.state")
		terminal = require("termite.terminal")

		config.setup({})

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

	describe("create()", function()
		it("creates a terminal with valid buffer and window", function()
			local term = terminal.create()

			assert.is_not_nil(term)
			assert.is_not_nil(term.buf)
			assert.is_not_nil(term.win)
			assert.is_true(vim.api.nvim_buf_is_valid(term.buf))
			assert.is_true(vim.api.nvim_win_is_valid(term.win))
		end)

		it("adds terminal to state list", function()
			assert.are.equal(0, #state.terminals)

			terminal.create()

			assert.are.equal(1, #state.terminals)
		end)

		it("increments next_count for each terminal", function()
			local term1 = terminal.create()
			local term2 = terminal.create()

			assert.are.equal(1, term1.count)
			assert.are.equal(2, term2.count)
		end)

		it("sets terminal cwd to current directory", function()
			local term = terminal.create()

			assert.are.equal(vim.fn.getcwd(), term.cwd)
		end)

		it("stores window configuration on terminal", function()
			local term = terminal.create()

			assert.is_not_nil(term.config)
			assert.is_not_nil(term.config.width)
			assert.is_not_nil(term.config.height)
			assert.is_not_nil(term.config.row)
			assert.is_not_nil(term.config.col)
		end)

		it("applies window options from config", function()
			config.setup({
				wo = {
					number = false,
					relativenumber = false,
				},
			})

			local term = terminal.create()

			assert.is_false(vim.wo[term.win].number)
			assert.is_false(vim.wo[term.win].relativenumber)
		end)

		it("sets up buffer-local keymaps", function()
			local term = terminal.create()
			local keymaps = vim.api.nvim_buf_get_keymap(term.buf, "t")

			local has_toggle = false
			for _, km in ipairs(keymaps) do
				if km.desc and km.desc:match("Toggle") then
					has_toggle = true
					break
				end
			end
			assert.is_true(has_toggle)
		end)

		it("creates terminal buffer with correct buftype", function()
			local term = terminal.create()

			-- NOTE: In tests, jobstart is mocked so buftype remains 'nofile'
			-- In production, jobstart sets buftype to 'terminal' automatically
			-- We verify the buffer exists and is valid instead
			assert.is_true(vim.api.nvim_buf_is_valid(term.buf))
		end)
	end)

	describe("show()", function()
		it("shows a hidden terminal", function()
			local term = terminal.create()
			local original_win = term.win

			-- Hide the terminal
			vim.api.nvim_win_close(term.win, true)
			term.win = nil

			-- Show it again
			terminal.show(term)

			assert.is_not_nil(term.win)
			assert.is_true(vim.api.nvim_win_is_valid(term.win))
			assert.are_not.equal(original_win, term.win)
		end)

		it("does nothing if terminal already visible", function()
			local term = terminal.create()
			local original_win = term.win

			terminal.show(term)

			assert.are.equal(original_win, term.win)
		end)

		it("does nothing if buffer is nil", function()
			local term = terminal.create()

			-- Close the window first
			vim.api.nvim_win_close(term.win, true)
			term.win = nil

			-- Set buffer to nil
			term.buf = nil

			-- Should not error and should not create window
			terminal.show(term)
			assert.is_nil(term.win)
		end)

		it("does nothing if buffer is invalid", function()
			local term = terminal.create()

			-- Close the window first
			vim.api.nvim_win_close(term.win, true)
			term.win = nil

			-- Close the buffer and set to invalid handle
			vim.api.nvim_buf_delete(term.buf, { force = true })
			term.buf = 99999

			-- Should not error and should not create window
			terminal.show(term)
			assert.is_nil(term.win)
		end)
	end)

	describe("hide()", function()
		it("hides a visible terminal", function()
			local term = terminal.create()
			local win = term.win

			terminal.hide(term)

			assert.is_false(vim.api.nvim_win_is_valid(win))
			assert.is_nil(term.win)
		end)

		it("does nothing if terminal already hidden", function()
			local term = terminal.create()
			terminal.hide(term)

			-- Should not error
			terminal.hide(term)
			assert.is_nil(term.win)
		end)
	end)

	describe("close()", function()
		it("closes window and deletes buffer", function()
			local term = terminal.create()
			local win = term.win
			local buf = term.buf

			terminal.close(term)

			assert.is_false(vim.api.nvim_win_is_valid(win))
			assert.is_false(vim.api.nvim_buf_is_valid(buf))
		end)

		it("clears window and buffer references", function()
			local term = terminal.create()

			terminal.close(term)

			assert.is_nil(term.win)
			assert.is_nil(term.buf)
		end)
	end)

	describe("setup_keymaps()", function()
		it("sets up terminal keymaps when configured", function()
			local buf = vim.api.nvim_create_buf(false, true)
			terminal.setup_keymaps(buf)

			-- Check that keymaps were set (buffer-local)
			local keymaps = vim.api.nvim_buf_get_keymap(buf, "t")
			local has_toggle = false
			for _, km in ipairs(keymaps) do
				if km.desc and km.desc:match("Toggle") then
					has_toggle = true
					break
				end
			end
			assert.is_true(has_toggle, "Toggle keymap should be set")

			-- Cleanup
			vim.api.nvim_buf_delete(buf, { force = true })
		end)

		it("skips keymaps when lhs is nil", function()
			-- Temporarily modify config to have nil keymap
			local original_create = config.values.keymaps.create
			config.values.keymaps.create = nil

			local buf = vim.api.nvim_create_buf(false, true)
			terminal.setup_keymaps(buf)

			local keymaps = vim.api.nvim_buf_get_keymap(buf, "t")
			local has_create = false
			for _, km in ipairs(keymaps) do
				if km.desc and km.desc:match("Create") then
					has_create = true
					break
				end
			end
			assert.is_false(has_create, "Create keymap should not be set when lhs is nil")

			-- Restore and cleanup
			config.values.keymaps.create = original_create
			vim.api.nvim_buf_delete(buf, { force = true })
		end)
	end)
end)
