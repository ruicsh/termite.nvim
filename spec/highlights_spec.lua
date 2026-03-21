describe("highlights module", function()
	local highlights
	local config

	before_each(function()
		package.loaded["termite.config"] = nil
		package.loaded["termite.highlights"] = nil
		config = require("termite.config")
		highlights = require("termite.highlights")
	end)

	describe("module constants", function()
		it("defines correct highlight group names", function()
			assert.are.equal("TermiteBorder", highlights.BORDER_ACTIVE)
			assert.are.equal("TermiteBorderNC", highlights.BORDER_INACTIVE)
			assert.are.equal("TermiteBorderSingle", highlights.BORDER_SINGLE)
			assert.are.equal("TermiteWinbar", highlights.WINBAR)
		end)
	end)

	describe("setup()", function()
		it("creates default highlight groups", function()
			config.setup({})
			highlights.setup()

			local active = vim.api.nvim_get_hl(0, { name = "TermiteBorder" })
			assert.are_not.equal(nil, active)
		end)

		it("applies user-provided highlight tables", function()
			config.setup({
				highlights = {
					border_active = { fg = "#ff0000", bg = "NONE" },
					border_inactive = { fg = "#888888", bg = "NONE" },
				},
			})
			highlights.setup()

			local active = vim.api.nvim_get_hl(0, { name = "TermiteBorder" })
			assert.are.equal(0xff0000, active.fg)
		end)
	end)

	describe("resolve_hl()", function()
		it("returns string config values as-is", function()
			local result = highlights.resolve_hl("ErrorMsg", highlights.BORDER_ACTIVE)
			assert.are.equal("ErrorMsg", result)
		end)

		it("returns default group for table config values", function()
			local result = highlights.resolve_hl({ fg = "#00ff00" }, highlights.BORDER_ACTIVE)
			assert.are.equal("TermiteBorder", result)
		end)

		it("returns default group for nil config values", function()
			local result = highlights.resolve_hl(nil, highlights.BORDER_ACTIVE)
			assert.are.equal("TermiteBorder", result)
		end)

		it("handles all highlight types", function()
			assert.are.equal("ErrorMsg", highlights.resolve_hl("ErrorMsg", highlights.BORDER_ACTIVE))
			assert.are.equal("TermiteBorder", highlights.resolve_hl({ link = "Foo" }, highlights.BORDER_ACTIVE))
			assert.are.equal("TermiteBorderNC", highlights.resolve_hl(nil, highlights.BORDER_INACTIVE))
			assert.are.equal("TermiteBorderSingle", highlights.resolve_hl({}, highlights.BORDER_SINGLE))
		end)
	end)
end)
