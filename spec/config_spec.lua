describe("config module", function()
	local config

	before_each(function()
		-- Reset config module to get fresh state
		package.loaded["termite.config"] = nil
		config = require("termite.config")
	end)

	describe("setup()", function()
		it("applies default values when called with no opts", function()
			config.setup()
			assert.are.equal(0.5, config.values.width)
			assert.are.equal(0.5, config.values.height)
			assert.are.equal("right", config.values.position)
			assert.are.equal("light", config.values.border)
			assert.are.equal(nil, config.values.shell)
			assert.are.equal(true, config.values.start_insert)
			assert.are.equal(true, config.values.winbar)
		end)

		it("merges user options with defaults", function()
			config.setup({
				width = 0.8,
				position = "left",
				shell = "/bin/zsh",
			})
			assert.are.equal(0.8, config.values.width)
			assert.are.equal("left", config.values.position)
			assert.are.equal("/bin/zsh", config.values.shell)
			assert.are.equal(0.5, config.values.height)
			assert.are.equal("light", config.values.border)
		end)

		it("preserves nested table defaults", function()
			config.setup({})
			assert.are.equal("<c-bslash>", config.values.keymaps.toggle)
			assert.are.equal("<c-t>", config.values.keymaps.create)
			assert.are.equal("<c-n>", config.values.keymaps.next)
			assert.are.equal("<c-p>", config.values.keymaps.prev)
			assert.are.equal("<c-e>", config.values.keymaps.focus_editor)
			assert.are.equal("<c-[>", config.values.keymaps.normal_mode)
			assert.are.equal("<c-z>", config.values.keymaps.maximize)
			assert.are.equal("q", config.values.keymaps.close)
		end)

		it("allows partial keymap overrides", function()
			config.setup({
				keymaps = {
					toggle = "<leader>t",
					create = "<leader>c",
				},
			})
			assert.are.equal("<leader>t", config.values.keymaps.toggle)
			assert.are.equal("<leader>c", config.values.keymaps.create)
			assert.are.equal("<c-n>", config.values.keymaps.next)
		end)

		it("allows partial window option overrides", function()
			config.setup({
				wo = {
					signcolumn = "no",
				},
			})
			assert.are.equal("no", config.values.wo.signcolumn)
		end)

		it("allows partial highlight overrides", function()
			config.setup({
				highlights = {
					border_active = { fg = "#00ff00", bg = "NONE" },
				},
			})
			assert.are.same({ fg = "#00ff00", bg = "NONE" }, config.values.highlights.border_active)
			assert.are.equal("TermiteBorderNC", config.values.highlights.border_inactive)
		end)

		it("handles all valid positions", function()
			for _, pos in ipairs({ "left", "right", "top", "bottom" }) do
				config.setup({ position = pos })
				assert.are.equal(pos, config.values.position)
			end
		end)

		it("handles all valid border styles", function()
			local styles = { "light", "heavy", "double", "double-dash", "triple-dash", "quadruple-dash" }
			for _, style in ipairs(styles) do
				config.setup({ border = style })
				assert.are.equal(style, config.values.border)
			end
		end)
	end)

	describe("get_border_chars()", function()
		it("returns border chars for default style (light)", function()
			config.setup({ border = "light" })
			local chars = config.get_border_chars()
			assert.are.equal("│", chars.vertical)
			assert.are.equal("─", chars.horizontal)
		end)

		it("returns border chars for heavy style", function()
			config.setup({ border = "heavy" })
			local chars = config.get_border_chars()
			assert.are.equal("┃", chars.vertical)
			assert.are.equal("━", chars.horizontal)
		end)

		it("returns border chars for double style", function()
			config.setup({ border = "double" })
			local chars = config.get_border_chars()
			assert.are.equal("║", chars.vertical)
			assert.are.equal("═", chars.horizontal)
		end)

		it("returns border chars for hyphenated styles", function()
			config.setup({ border = "double-dash" })
			local chars = config.get_border_chars()
			assert.are.equal("╎", chars.vertical)

			config.setup({ border = "triple-dash" })
			chars = config.get_border_chars()
			assert.are.equal("┆", chars.vertical)

			config.setup({ border = "quadruple-dash" })
			chars = config.get_border_chars()
			assert.are.equal("┊", chars.vertical)
		end)

		it("falls back to light style for unknown style", function()
			config.setup({ border = "unknown" })
			local chars = config.get_border_chars()
			assert.are.equal("│", chars.vertical)
		end)

		it("returns the same table reference for same style", function()
			config.setup({ border = "light" })
			local chars1 = config.get_border_chars()
			local chars2 = config.get_border_chars()
			assert.are.equal(chars1.vertical, chars2.vertical)
		end)
	end)

	describe("edge cases", function()
		it("handles empty table setup", function()
			config.setup({})
			assert.are.equal(0.5, config.values.width)
			assert.are.equal("right", config.values.position)
		end)

		it("handles width and height edge values", function()
			config.setup({ width = 0.0 })
			assert.are.equal(0.0, config.values.width)

			config.setup({ width = 1.0 })
			assert.are.equal(1.0, config.values.width)

			config.setup({ height = 0.0 })
			assert.are.equal(0.0, config.values.height)

			config.setup({ height = 1.0 })
			assert.are.equal(1.0, config.values.height)
		end)
	end)
end)
