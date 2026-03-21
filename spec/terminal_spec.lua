describe("terminal module", function()
	local terminal

	before_each(function()
		terminal = require("termite.terminal")
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
			local config = require("termite.config")
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
