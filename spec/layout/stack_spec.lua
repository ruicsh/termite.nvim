describe("layout.stack module", function()
	local layout
	local config
	local highlights

	local saved_columns, saved_lines, saved_cmdheight, saved_laststatus, saved_showtabline

	local function setup_vim_mock(columns, lines, cmdheight, laststatus, showtabline)
		vim.o.columns = columns or 100
		vim.o.lines = lines or 50
		vim.o.cmdheight = cmdheight or 1
		vim.o.laststatus = laststatus or 2
		vim.o.showtabline = showtabline or 1
	end

	before_each(function()
		package.loaded["termite.config"] = nil
		package.loaded["termite.highlights"] = nil
		package.loaded["termite.layout"] = nil
		package.loaded["termite.state"] = nil

		-- Save original values
		saved_columns = vim.o.columns
		saved_lines = vim.o.lines
		saved_cmdheight = vim.o.cmdheight
		saved_laststatus = vim.o.laststatus
		saved_showtabline = vim.o.showtabline

		config = require("termite.config")
		highlights = require("termite.highlights")
		layout = require("termite.layout")

		-- Set default config for tests
		config.setup({ position = "right", width = 0.5 })
	end)

	after_each(function()
		-- Restore original values
		vim.o.columns = saved_columns
		vim.o.lines = saved_lines
		vim.o.cmdheight = saved_cmdheight
		vim.o.laststatus = saved_laststatus
		vim.o.showtabline = saved_showtabline
	end)

	describe("get_win_config()", function()
		it("returns correct config for single terminal", function()
			setup_vim_mock(100, 50, 1, 2, 1)

			local win_config = layout.get_win_config(1, 1)

			assert.are.equal("NE", win_config.anchor)
			assert.are.equal("editor", win_config.relative)
			assert.are.equal("minimal", win_config.style)
			assert.are.equal(50, win_config.zindex)
			assert.are.equal(50, win_config.width)
			assert.are.equal(100, win_config.col)
		end)

		it("returns correct height for single terminal", function()
			setup_vim_mock(100, 50, 1, 2, 1)

			local win_config = layout.get_win_config(1, 1)

			-- editor_height = 50 - 1 (cmdheight) - 1 (laststatus) = 48
			-- showtabline = 1 with 1 tabpage doesn't subtract
			-- Usable height = 48 - 1 (border) = 47
			assert.are.equal(47, win_config.height)
		end)

		it("returns correct config for first of two terminals", function()
			setup_vim_mock(100, 50, 1, 2, 1)

			local win_config_1 = layout.get_win_config(1, 2)

			assert.are.equal("NE", win_config_1.anchor)
			assert.are.equal(0, win_config_1.row)
			-- editor_height = 48, usable = 48 - 2 = 46, each = 23
			assert.are.equal(23, win_config_1.height)
		end)

		it("gives last terminal remaining space", function()
			setup_vim_mock(100, 50, 1, 2, 1)

			local total = 3
			local editor_height = 50 - 1 - 1 -- 48
			local usable_height = editor_height - total -- 45
			local each_height = math.floor(usable_height / total) -- 15

			local win_config_1 = layout.get_win_config(1, total)
			local win_config_2 = layout.get_win_config(2, total)
			local win_config_3 = layout.get_win_config(3, total)

			assert.are.equal(each_height, win_config_1.height)
			assert.are.equal(each_height, win_config_2.height)
			-- Last terminal gets remaining: 45 - (15 * 2) = 15
			assert.are.equal(15, win_config_3.height)
		end)

		it("calculates correct row positions", function()
			setup_vim_mock(100, 50, 1, 2, 1)

			local win_config_1 = layout.get_win_config(1, 3)
			local win_config_2 = layout.get_win_config(2, 3)
			local win_config_3 = layout.get_win_config(3, 3)

			-- Row accumulates: (index - 1) * (height + 1)
			-- Each height = 15, so position 2 = 15 + 1 = 16, position 3 = 16 + 15 + 1 = 32
			assert.are.equal(0, win_config_1.row)
			assert.are.equal(16, win_config_2.row)
			assert.are.equal(32, win_config_3.row)
		end)

		it("sets invisible last terminal border (space chars)", function()
			setup_vim_mock(100, 50, 1, 2, 1)

			local win_config = layout.get_win_config(3, 3)

			-- Last terminal should have spaces for bottom border
			assert.are.equal(" ", win_config.border[5])
			assert.are.equal(" ", win_config.border[6])
		end)

		it("uses vertical separator between terminals", function()
			setup_vim_mock(100, 50, 1, 2, 1)

			local win_config_1 = layout.get_win_config(1, 2)
			local win_config_2 = layout.get_win_config(2, 2)

			-- First terminal has horizontal separator at bottom
			assert.are.equal("─", win_config_1.border[5])
			assert.are.equal("─", win_config_1.border[6])
			-- Last terminal has no separator (spaces)
			assert.are.equal(" ", win_config_2.border[5])
			assert.are.equal(" ", win_config_2.border[6])
		end)

		it("handles custom width fraction", function()
			-- Reload layout after config change
			config.setup({ position = "right", width = 0.8 })
			package.loaded["termite.layout"] = nil
			package.loaded["termite.layout.stack"] = nil
			layout = require("termite.layout")

			setup_vim_mock(100, 50, 1, 2, 1)

			local win_config = layout.get_win_config(1, 1)
			assert.are.equal(80, win_config.width)
		end)

		it("handles minimum dimensions", function()
			config.setup({ position = "right", width = 0.1 })
			package.loaded["termite.layout"] = nil
			package.loaded["termite.layout.stack"] = nil
			layout = require("termite.layout")

			setup_vim_mock(80, 24, 1, 2, 1)

			local win_config = layout.get_win_config(1, 1)
			assert.are.equal(8, win_config.width)
		end)

		it("correctly accounts for cmdheight", function()
			setup_vim_mock(100, 50, 2, 2, 1)

			local win_config = layout.get_win_config(1, 1)
			local editor_height = 50 - 2 - 1 -- 47
			local usable_height = editor_height - 1 -- 46
			assert.are.equal(usable_height, win_config.height)
		end)

		it("correctly accounts for laststatus=0", function()
			setup_vim_mock(100, 50, 1, 0, 1)

			local win_config = layout.get_win_config(1, 1)
			local editor_height = 50 - 1 - 0 -- 49
			local usable_height = editor_height - 1 -- 48
			assert.are.equal(usable_height, win_config.height)
		end)

		it("correctly accounts for showtabline=2", function()
			setup_vim_mock(100, 50, 1, 2, 2)

			local win_config = layout.get_win_config(1, 1)
			local editor_height = 50 - 1 - 1 - 1 -- 47
			local usable_height = editor_height - 1 -- 46
			assert.are.equal(usable_height, win_config.height)
		end)
	end)

	describe("build_highlighted_border()", function()
		before_each(function()
			config.setup({})
			highlights.setup()
		end)

		it("applies active highlight to outer edge for active terminal", function()
			-- Position 8 is the outer edge for "right" position (left border)
			local border = { "", "", "│", "│", "│", "─", "", "│" }
			local result = layout.build_highlighted_border(border, "right", "active")

			assert.are.equal("table", type(result[8]))
			assert.are.equal(2, #result[8])
		end)

		it("applies inactive highlight for inactive terminal", function()
			local border = { "", "", "│", "│", "│", "─", "", "│" }
			local result = layout.build_highlighted_border(border, "right", "inactive")

			assert.are.equal("table", type(result[8]))
			assert.are.equal(2, #result[8])
		end)

		it("applies single highlight for single terminal", function()
			local border = { "", "", "│", "│", "│", "─", "", "│" }
			local result = layout.build_highlighted_border(border, "right", "single")

			assert.are.equal("table", type(result[8]))
			assert.are.equal(2, #result[8])
		end)

		describe("position-specific outer edges", function()
			it("right position highlights left border (position 8)", function()
				local border = { "", "", "│", "│", "│", "─", "", "│" }
				local result = layout.build_highlighted_border(border, "right", "active")

				assert.are.equal("table", type(result[8]))
			end)

			it("left position highlights right border (position 4)", function()
				local border = { "", "", "│", "│", "│", "─", "", "" }
				local result = layout.build_highlighted_border(border, "left", "active")

				assert.are.equal("table", type(result[4]))
			end)

			it("top position highlights bottom border (position 6)", function()
				local border = { "─", "─", "│", "│", "┬", "─", "─", "" }
				local result = layout.build_highlighted_border(border, "top", "active")

				assert.are.equal("table", type(result[6]))
			end)

			it("bottom position highlights top border (position 2)", function()
				local border = { "─", "─", "│", "│", "┬", "─", "─", "" }
				local result = layout.build_highlighted_border(border, "bottom", "active")

				assert.are.equal("table", type(result[2]))
			end)
		end)
	end)
end)
