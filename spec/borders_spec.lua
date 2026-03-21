describe("borders module", function()
	local borders = require("termite.borders")

	describe("border character sets", function()
		it("returns light border chars", function()
			assert.are.equal("│", borders.light.vertical)
			assert.are.equal("─", borders.light.horizontal)
			assert.are.equal("├", borders.light.vertical_left)
			assert.are.equal("┤", borders.light.vertical_right)
			assert.are.equal("┬", borders.light.horizontal_down)
			assert.are.equal("┴", borders.light.horizontal_up)
		end)

		it("returns heavy border chars", function()
			assert.are.equal("┃", borders.heavy.vertical)
			assert.are.equal("━", borders.heavy.horizontal)
			assert.are.equal("┣", borders.heavy.vertical_left)
			assert.are.equal("┫", borders.heavy.vertical_right)
		end)

		it("returns double border chars", function()
			assert.are.equal("║", borders.double.vertical)
			assert.are.equal("═", borders.double.horizontal)
			assert.are.equal("╠", borders.double.vertical_left)
			assert.are.equal("╣", borders.double.vertical_right)
		end)

		it("returns double-dash border chars", function()
			assert.are.equal("╎", borders["double-dash"].vertical)
			assert.are.equal("╌", borders["double-dash"].horizontal)
			assert.are.equal("╟", borders["double-dash"].vertical_left)
			assert.are.equal("╢", borders["double-dash"].vertical_right)
		end)

		it("returns triple-dash border chars", function()
			assert.are.equal("┆", borders["triple-dash"].vertical)
			assert.are.equal("┄", borders["triple-dash"].horizontal)
			assert.are.equal("┝", borders["triple-dash"].vertical_left)
			assert.are.equal("┥", borders["triple-dash"].vertical_right)
		end)

		it("returns quadruple-dash border chars", function()
			assert.are.equal("┊", borders["quadruple-dash"].vertical)
			assert.are.equal("┈", borders["quadruple-dash"].horizontal)
			assert.are.equal("┝", borders["quadruple-dash"].vertical_left)
			assert.are.equal("┥", borders["quadruple-dash"].vertical_right)
		end)
	end)

	describe("edge cases", function()
		it("all border styles have all required keys", function()
			local required_keys = {
				"vertical",
				"horizontal",
				"vertical_left",
				"vertical_right",
				"horizontal_down",
				"horizontal_up",
			}
			for style, chars in pairs(borders) do
				for _, key in ipairs(required_keys) do
					assert.are_not.equal(nil, chars[key], string.format("Style '%s' missing key '%s'", style, key))
				end
			end
		end)

		it("all border chars are single-width characters", function()
			for style, chars in pairs(borders) do
				for key, char in pairs(chars) do
					assert.are.equal(1, vim.fn.strcharlen(char), string.format("Style '%s' key '%s' is not single-width", style, key))
				end
			end
		end)
	end)
end)
