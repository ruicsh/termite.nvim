describe("layout.tmux border logic", function()
	local tmux
	local config
	local state
	local constants

	local saved_columns, saved_lines, saved_cmdheight, saved_laststatus, saved_showtabline

	before_each(function()
		package.loaded["termite.config"] = nil
		package.loaded["termite.state"] = nil
		package.loaded["termite.terminal"] = nil
		package.loaded["termite.constants"] = nil
		package.loaded["termite.layout.tmux"] = nil

		saved_columns = vim.o.columns
		saved_lines = vim.o.lines
		saved_cmdheight = vim.o.cmdheight
		saved_laststatus = vim.o.laststatus
		saved_showtabline = vim.o.showtabline

		config = require("termite.config")
		config.setup({ layout = "tmux", position = "right", width = 0.5, height = 0.5 })

		state = require("termite.state")
		constants = require("termite.constants")
		tmux = require("termite.layout.tmux")

		state.pane_tree = nil
		state.terminals = {}
		state.next_term_id = 1
		state.next_count = 1
		state.visible = false
		state.last_focused_term_id = nil
		state.maximized_term_id = nil
	end)

	after_each(function()
		vim.o.columns = saved_columns
		vim.o.lines = saved_lines
		vim.o.cmdheight = saved_cmdheight
		vim.o.laststatus = saved_laststatus
		vim.o.showtabline = saved_showtabline
	end)

	describe("build_pane_border - single pane root", function()
		it("position=right has outer_left edge drawn", function()
			local root_rect = { row = 0, col = 50, width = 50, height = 48 }
			local all_geoms = { [1] = root_rect }
			local border = tmux._test.build_pane_border(root_rect, root_rect, "right", all_geoms)
			local chars = config.get_border_chars()

			assert.are.equal(chars.vertical, border[constants.BORDER_LEFT])
			assert.are.equal("", border[constants.BORDER_RIGHT])
			assert.are.equal("", border[constants.BORDER_TOP])
			assert.are.equal("", border[constants.BORDER_BOTTOM])
		end)

		it("position=right has no corners (single edge)", function()
			local root_rect = { row = 0, col = 50, width = 50, height = 48 }
			local all_geoms = { [1] = root_rect }
			local border = tmux._test.build_pane_border(root_rect, root_rect, "right", all_geoms)

			assert.are.equal("", border[constants.BORDER_TOP_LEFT])
			assert.are.equal("", border[constants.BORDER_TOP_RIGHT])
			assert.are.equal("", border[constants.BORDER_BOTTOM_LEFT])
			assert.are.equal("", border[constants.BORDER_BOTTOM_RIGHT])
		end)

		it("position=left has outer_right edge drawn", function()
			local root_rect = { row = 0, col = 0, width = 50, height = 48 }
			local all_geoms = { [1] = root_rect }
			local border = tmux._test.build_pane_border(root_rect, root_rect, "left", all_geoms)
			local chars = config.get_border_chars()

			assert.are.equal("", border[constants.BORDER_LEFT])
			assert.are.equal(chars.vertical, border[constants.BORDER_RIGHT])
			assert.are.equal("", border[constants.BORDER_TOP])
			assert.are.equal("", border[constants.BORDER_BOTTOM])
		end)

		it("position=left has no corners (single edge)", function()
			local root_rect = { row = 0, col = 0, width = 50, height = 48 }
			local all_geoms = { [1] = root_rect }
			local border = tmux._test.build_pane_border(root_rect, root_rect, "left", all_geoms)

			assert.are.equal("", border[constants.BORDER_TOP_LEFT])
			assert.are.equal("", border[constants.BORDER_TOP_RIGHT])
			assert.are.equal("", border[constants.BORDER_BOTTOM_LEFT])
			assert.are.equal("", border[constants.BORDER_BOTTOM_RIGHT])
		end)

		it("position=bottom has outer_top edge drawn", function()
			local root_rect = { row = 24, col = 0, width = 100, height = 24 }
			local all_geoms = { [1] = root_rect }
			local border = tmux._test.build_pane_border(root_rect, root_rect, "bottom", all_geoms)
			local chars = config.get_border_chars()

			assert.are.equal("", border[constants.BORDER_LEFT])
			assert.are.equal("", border[constants.BORDER_RIGHT])
			assert.are.equal(chars.horizontal, border[constants.BORDER_TOP])
			assert.are.equal("", border[constants.BORDER_BOTTOM])
		end)

		it("position=bottom has no corners (single edge)", function()
			local root_rect = { row = 24, col = 0, width = 100, height = 24 }
			local all_geoms = { [1] = root_rect }
			local border = tmux._test.build_pane_border(root_rect, root_rect, "bottom", all_geoms)

			assert.are.equal("", border[constants.BORDER_TOP_LEFT])
			assert.are.equal("", border[constants.BORDER_TOP_RIGHT])
			assert.are.equal("", border[constants.BORDER_BOTTOM_LEFT])
			assert.are.equal("", border[constants.BORDER_BOTTOM_RIGHT])
		end)

		it("position=top has outer_bottom edge drawn", function()
			local root_rect = { row = 0, col = 0, width = 100, height = 24 }
			local all_geoms = { [1] = root_rect }
			local border = tmux._test.build_pane_border(root_rect, root_rect, "top", all_geoms)
			local chars = config.get_border_chars()

			assert.are.equal("", border[constants.BORDER_LEFT])
			assert.are.equal("", border[constants.BORDER_RIGHT])
			assert.are.equal("", border[constants.BORDER_TOP])
			assert.are.equal(chars.horizontal, border[constants.BORDER_BOTTOM])
		end)

		it("position=top has no corners (single edge)", function()
			local root_rect = { row = 0, col = 0, width = 100, height = 24 }
			local all_geoms = { [1] = root_rect }
			local border = tmux._test.build_pane_border(root_rect, root_rect, "top", all_geoms)

			assert.are.equal("", border[constants.BORDER_TOP_LEFT])
			assert.are.equal("", border[constants.BORDER_TOP_RIGHT])
			assert.are.equal("", border[constants.BORDER_BOTTOM_LEFT])
			assert.are.equal("", border[constants.BORDER_BOTTOM_RIGHT])
		end)
	end)

	describe("build_pane_border - two panes vertical split", function()
		local root_rect = { row = 0, col = 50, width = 50, height = 48 }

		it("left pane has outer_left and inner_right edges drawn", function()
			local left_pane = { row = 0, col = 50, width = 25, height = 48 }
			local right_pane = { row = 0, col = 75, width = 25, height = 48 }
			local all_geoms = { [1] = left_pane, [2] = right_pane }
			local border = tmux._test.build_pane_border(left_pane, root_rect, "right", all_geoms)
			local chars = config.get_border_chars()

			assert.are.equal(chars.vertical, border[constants.BORDER_LEFT])
			assert.are.equal(chars.vertical, border[constants.BORDER_RIGHT])
			assert.are.equal("", border[constants.BORDER_TOP])
			assert.are.equal("", border[constants.BORDER_BOTTOM])
		end)

		it("right pane has inner_left edge drawn", function()
			local left_pane = { row = 0, col = 50, width = 25, height = 48 }
			local right_pane = { row = 0, col = 75, width = 25, height = 48 }
			local all_geoms = { [1] = left_pane, [2] = right_pane }
			local border = tmux._test.build_pane_border(right_pane, root_rect, "right", all_geoms)
			local chars = config.get_border_chars()

			assert.are.equal(chars.vertical, border[constants.BORDER_LEFT])
			assert.are.equal("", border[constants.BORDER_RIGHT])
			assert.are.equal("", border[constants.BORDER_TOP])
			assert.are.equal("", border[constants.BORDER_BOTTOM])
		end)

		it("left pane has no corners (no top/bottom edges)", function()
			local left_pane = { row = 0, col = 50, width = 25, height = 48 }
			local right_pane = { row = 0, col = 75, width = 25, height = 48 }
			local all_geoms = { [1] = left_pane, [2] = right_pane }
			local border = tmux._test.build_pane_border(left_pane, root_rect, "right", all_geoms)

			assert.are.equal("", border[constants.BORDER_TOP_LEFT])
			assert.are.equal("", border[constants.BORDER_TOP_RIGHT])
			assert.are.equal("", border[constants.BORDER_BOTTOM_LEFT])
			assert.are.equal("", border[constants.BORDER_BOTTOM_RIGHT])
		end)

		it("right pane has no corners (no top/bottom edges)", function()
			local left_pane = { row = 0, col = 50, width = 25, height = 48 }
			local right_pane = { row = 0, col = 75, width = 25, height = 48 }
			local all_geoms = { [1] = left_pane, [2] = right_pane }
			local border = tmux._test.build_pane_border(right_pane, root_rect, "right", all_geoms)

			assert.are.equal("", border[constants.BORDER_TOP_LEFT])
			assert.are.equal("", border[constants.BORDER_TOP_RIGHT])
			assert.are.equal("", border[constants.BORDER_BOTTOM_LEFT])
			assert.are.equal("", border[constants.BORDER_BOTTOM_RIGHT])
		end)

		it("does not detect false neighbors when panes do not touch", function()
			local pane1 = { row = 0, col = 50, width = 20, height = 48 }
			local pane2 = { row = 0, col = 80, width = 20, height = 48 }
			local all_geoms = { [1] = pane1, [2] = pane2 }
			local border = tmux._test.build_pane_border(pane1, root_rect, "right", all_geoms)
			local chars = config.get_border_chars()

			assert.are.equal(chars.vertical, border[constants.BORDER_LEFT])
			assert.are.equal("", border[constants.BORDER_RIGHT])
		end)
	end)

	describe("build_pane_border - two panes horizontal split", function()
		local root_rect = { row = 24, col = 0, width = 100, height = 24 }

		it("top pane has outer_top and inner_bottom edges drawn", function()
			local top_pane = { row = 24, col = 0, width = 100, height = 12 }
			local bottom_pane = { row = 36, col = 0, width = 100, height = 12 }
			local all_geoms = { [1] = top_pane, [2] = bottom_pane }
			local border = tmux._test.build_pane_border(top_pane, root_rect, "bottom", all_geoms)
			local chars = config.get_border_chars()

			assert.are.equal("", border[constants.BORDER_LEFT])
			assert.are.equal("", border[constants.BORDER_RIGHT])
			assert.are.equal(chars.horizontal, border[constants.BORDER_TOP])
			assert.are.equal(chars.horizontal, border[constants.BORDER_BOTTOM])
		end)

		it("bottom pane has inner_top edge drawn", function()
			local top_pane = { row = 24, col = 0, width = 100, height = 12 }
			local bottom_pane = { row = 36, col = 0, width = 100, height = 12 }
			local all_geoms = { [1] = top_pane, [2] = bottom_pane }
			local border = tmux._test.build_pane_border(bottom_pane, root_rect, "bottom", all_geoms)
			local chars = config.get_border_chars()

			assert.are.equal("", border[constants.BORDER_LEFT])
			assert.are.equal("", border[constants.BORDER_RIGHT])
			assert.are.equal(chars.horizontal, border[constants.BORDER_TOP])
			assert.are.equal("", border[constants.BORDER_BOTTOM])
		end)

		it("top pane has no corners (no left/right edges)", function()
			local top_pane = { row = 24, col = 0, width = 100, height = 12 }
			local bottom_pane = { row = 36, col = 0, width = 100, height = 12 }
			local all_geoms = { [1] = top_pane, [2] = bottom_pane }
			local border = tmux._test.build_pane_border(top_pane, root_rect, "bottom", all_geoms)

			assert.are.equal("", border[constants.BORDER_TOP_LEFT])
			assert.are.equal("", border[constants.BORDER_TOP_RIGHT])
			assert.are.equal("", border[constants.BORDER_BOTTOM_LEFT])
			assert.are.equal("", border[constants.BORDER_BOTTOM_RIGHT])
		end)

		it("bottom pane has no corners (no left/right edges)", function()
			local top_pane = { row = 24, col = 0, width = 100, height = 12 }
			local bottom_pane = { row = 36, col = 0, width = 100, height = 12 }
			local all_geoms = { [1] = top_pane, [2] = bottom_pane }
			local border = tmux._test.build_pane_border(bottom_pane, root_rect, "bottom", all_geoms)

			assert.are.equal("", border[constants.BORDER_TOP_LEFT])
			assert.are.equal("", border[constants.BORDER_TOP_RIGHT])
			assert.are.equal("", border[constants.BORDER_BOTTOM_LEFT])
			assert.are.equal("", border[constants.BORDER_BOTTOM_RIGHT])
		end)
	end)

	describe("build_pane_border - four panes grid layout", function()
		local root_rect = { row = 0, col = 50, width = 50, height = 48 }

		it("top-left pane has outer_left, inner_right, and inner_bottom edges", function()
			local tl = { row = 0, col = 50, width = 25, height = 24 }
			local tr = { row = 0, col = 75, width = 25, height = 24 }
			local bl = { row = 24, col = 50, width = 25, height = 24 }
			local br = { row = 24, col = 75, width = 25, height = 24 }
			local all_geoms = { [1] = tl, [2] = tr, [3] = bl, [4] = br }
			local border = tmux._test.build_pane_border(tl, root_rect, "right", all_geoms)
			local chars = config.get_border_chars()

			assert.are.equal(chars.vertical, border[constants.BORDER_LEFT])
			assert.are.equal(chars.vertical, border[constants.BORDER_RIGHT])
			assert.are.equal("", border[constants.BORDER_TOP])
			assert.are.equal(chars.horizontal, border[constants.BORDER_BOTTOM])
		end)

		it("top-right pane has inner_left and inner_bottom edges", function()
			local tl = { row = 0, col = 50, width = 25, height = 24 }
			local tr = { row = 0, col = 75, width = 25, height = 24 }
			local bl = { row = 24, col = 50, width = 25, height = 24 }
			local br = { row = 24, col = 75, width = 25, height = 24 }
			local all_geoms = { [1] = tl, [2] = tr, [3] = bl, [4] = br }
			local border = tmux._test.build_pane_border(tr, root_rect, "right", all_geoms)
			local chars = config.get_border_chars()

			assert.are.equal(chars.vertical, border[constants.BORDER_LEFT])
			assert.are.equal("", border[constants.BORDER_RIGHT])
			assert.are.equal("", border[constants.BORDER_TOP])
			assert.are.equal(chars.horizontal, border[constants.BORDER_BOTTOM])
		end)

		it("bottom-left pane has outer_left and inner_right edges", function()
			local tl = { row = 0, col = 50, width = 25, height = 24 }
			local tr = { row = 0, col = 75, width = 25, height = 24 }
			local bl = { row = 24, col = 50, width = 25, height = 24 }
			local br = { row = 24, col = 75, width = 25, height = 24 }
			local all_geoms = { [1] = tl, [2] = tr, [3] = bl, [4] = br }
			local border = tmux._test.build_pane_border(bl, root_rect, "right", all_geoms)
			local chars = config.get_border_chars()

			assert.are.equal(chars.vertical, border[constants.BORDER_LEFT])
			assert.are.equal(chars.vertical, border[constants.BORDER_RIGHT])
			assert.are.equal(chars.horizontal, border[constants.BORDER_TOP])
			assert.are.equal("", border[constants.BORDER_BOTTOM])
		end)

		it("bottom-right pane has inner_left and inner_top edges", function()
			local tl = { row = 0, col = 50, width = 25, height = 24 }
			local tr = { row = 0, col = 75, width = 25, height = 24 }
			local bl = { row = 24, col = 50, width = 25, height = 24 }
			local br = { row = 24, col = 75, width = 25, height = 24 }
			local all_geoms = { [1] = tl, [2] = tr, [3] = bl, [4] = br }
			local border = tmux._test.build_pane_border(br, root_rect, "right", all_geoms)
			local chars = config.get_border_chars()

			assert.are.equal(chars.vertical, border[constants.BORDER_LEFT])
			assert.are.equal("", border[constants.BORDER_RIGHT])
			assert.are.equal(chars.horizontal, border[constants.BORDER_TOP])
			assert.are.equal("", border[constants.BORDER_BOTTOM])
		end)

		it("top-left pane has no corners (no top edge, only left/inner edges)", function()
			local tl = { row = 0, col = 50, width = 25, height = 24 }
			local tr = { row = 0, col = 75, width = 25, height = 24 }
			local bl = { row = 24, col = 50, width = 25, height = 24 }
			local br = { row = 24, col = 75, width = 25, height = 24 }
			local all_geoms = { [1] = tl, [2] = tr, [3] = bl, [4] = br }
			local border = tmux._test.build_pane_border(tl, root_rect, "right", all_geoms)

			assert.are.equal("", border[constants.BORDER_TOP_LEFT])
			assert.are.equal("", border[constants.BORDER_TOP_RIGHT])
		end)

		it("bottom-left pane has corners where vertical and horizontal edges meet", function()
			local tl = { row = 0, col = 50, width = 25, height = 24 }
			local tr = { row = 0, col = 75, width = 25, height = 24 }
			local bl = { row = 24, col = 50, width = 25, height = 24 }
			local br = { row = 24, col = 75, width = 25, height = 24 }
			local all_geoms = { [1] = tl, [2] = tr, [3] = bl, [4] = br }
			local border = tmux._test.build_pane_border(bl, root_rect, "right", all_geoms)
			local chars = config.get_border_chars()

			-- bottom-left pane has: left edge (outer) and right edge (inner) and top edge (inner)
			-- Corners: top-left (outer_left + inner_top), top-right (inner_right + inner_top)
			assert.are.equal(chars.vertical_left, border[constants.BORDER_TOP_LEFT])
			assert.are.equal(chars.cross, border[constants.BORDER_TOP_RIGHT])
		end)
	end)

	describe("build_pane_border - neighbor detection edge cases", function()
		local root_rect = { row = 0, col = 50, width = 50, height = 48 }

		it("does not detect neighbor when other pane is offset vertically", function()
			local pane1 = { row = 0, col = 50, width = 20, height = 20 }
			local pane2 = { row = 25, col = 75, width = 20, height = 20 }
			local all_geoms = { [1] = pane1, [2] = pane2 }
			local border = tmux._test.build_pane_border(pane1, root_rect, "right", all_geoms)
			local chars = config.get_border_chars()

			assert.are.equal(chars.vertical, border[constants.BORDER_LEFT])
			assert.are.equal("", border[constants.BORDER_RIGHT])
		end)

		it("detects partial overlap as neighbor", function()
			local pane1 = { row = 0, col = 50, width = 20, height = 30 }
			local pane2 = { row = 20, col = 70, width = 20, height = 28 }
			local all_geoms = { [1] = pane1, [2] = pane2 }
			local border = tmux._test.build_pane_border(pane1, root_rect, "right", all_geoms)
			local chars = config.get_border_chars()

			assert.are.equal(chars.vertical, border[constants.BORDER_RIGHT])
		end)

		it("handles empty all_geometries table gracefully", function()
			local pane = { row = 0, col = 50, width = 50, height = 48 }
			local all_geoms = {}
			local border = tmux._test.build_pane_border(pane, root_rect, "right", all_geoms)
			local chars = config.get_border_chars()

			assert.are.equal(chars.vertical, border[constants.BORDER_LEFT])
			assert.are.equal("", border[constants.BORDER_RIGHT])
		end)

		it("handles nil all_geometries gracefully", function()
			local pane = { row = 0, col = 50, width = 50, height = 48 }
			local border = tmux._test.build_pane_border(pane, root_rect, "right", nil)
			local chars = config.get_border_chars()

			assert.are.equal(chars.vertical, border[constants.BORDER_LEFT])
			assert.are.equal("", border[constants.BORDER_RIGHT])
		end)
	end)

	describe("build_pane_border - position edge flag logic", function()
		it("position=right marks left edge as outer when at root col", function()
			local pane = { row = 0, col = 50, width = 50, height = 48 }
			local root = { row = 0, col = 50, width = 50, height = 48 }
			local border = tmux._test.build_pane_border(pane, root, "right", {})
			local chars = config.get_border_chars()

			assert.are.equal(chars.vertical, border[constants.BORDER_LEFT])
		end)

		it("position=left marks right edge as outer when at root col + width", function()
			local pane = { row = 0, col = 0, width = 50, height = 48 }
			local root = { row = 0, col = 0, width = 50, height = 48 }
			local border = tmux._test.build_pane_border(pane, root, "left", {})
			local chars = config.get_border_chars()

			assert.are.equal(chars.vertical, border[constants.BORDER_RIGHT])
		end)

		it("position=top marks bottom edge as outer when at root row + height", function()
			local pane = { row = 0, col = 0, width = 100, height = 24 }
			local root = { row = 0, col = 0, width = 100, height = 24 }
			local border = tmux._test.build_pane_border(pane, root, "top", {})
			local chars = config.get_border_chars()

			assert.are.equal(chars.horizontal, border[constants.BORDER_BOTTOM])
		end)

		it("position=bottom marks top edge as outer when at root row", function()
			local pane = { row = 24, col = 0, width = 100, height = 24 }
			local root = { row = 24, col = 0, width = 100, height = 24 }
			local border = tmux._test.build_pane_border(pane, root, "bottom", {})
			local chars = config.get_border_chars()

			assert.are.equal(chars.horizontal, border[constants.BORDER_TOP])
		end)
	end)

	describe("build_pane_border - border array structure", function()
		local root_rect = { row = 0, col = 50, width = 50, height = 48 }
		local all_geoms = { [1] = root_rect }

		it("returns array with 8 elements", function()
			local border = tmux._test.build_pane_border(root_rect, root_rect, "right", all_geoms)
			assert.are.equal(8, #border)
		end)

		it("returns string values for edges", function()
			local border = tmux._test.build_pane_border(root_rect, root_rect, "right", all_geoms)
			assert.are.equal("string", type(border[constants.BORDER_LEFT]))
		end)

		it("returns string values for corners", function()
			local border = tmux._test.build_pane_border(root_rect, root_rect, "right", all_geoms)
			assert.are.equal("string", type(border[constants.BORDER_TOP_LEFT]))
		end)
	end)

	describe("corner character selection logic", function()
		local chars

		before_each(function()
			chars = config.get_border_chars()
		end)

		it("top-left corner with outer_left + inner_top uses vertical_left", function()
			local pane = { row = 24, col = 50, width = 25, height = 24 }
			local root = { row = 0, col = 50, width = 50, height = 48 }
			local above_pane = { row = 0, col = 50, width = 25, height = 24 }
			local all_geoms = { [1] = above_pane, [2] = pane }
			local border = tmux._test.build_pane_border(pane, root, "right", all_geoms)

			assert.are.equal(chars.vertical_left, border[constants.BORDER_TOP_LEFT])
		end)

		it("top-right corner with inner_right + inner_top uses cross", function()
			local tl = { row = 0, col = 50, width = 25, height = 24 }
			local tr = { row = 0, col = 75, width = 25, height = 24 }
			local bl = { row = 24, col = 50, width = 25, height = 24 }
			local br = { row = 24, col = 75, width = 25, height = 24 }
			local all_geoms = { [1] = tl, [2] = tr, [3] = bl, [4] = br }
			local root = { row = 0, col = 50, width = 50, height = 48 }
			local border = tmux._test.build_pane_border(bl, root, "right", all_geoms)

			-- bottom-left pane: left=outer_left, right=inner_right, top=inner_top
			-- top-right corner: inner_right + inner_top = cross
			assert.are.equal(chars.cross, border[constants.BORDER_TOP_RIGHT])
		end)

		it("bottom-left corner with outer_left + inner_bottom uses vertical_left", function()
			local pane = { row = 0, col = 50, width = 25, height = 24 }
			local root = { row = 0, col = 50, width = 50, height = 48 }
			local below_pane = { row = 24, col = 50, width = 25, height = 24 }
			local all_geoms = { [1] = pane, [2] = below_pane }
			local border = tmux._test.build_pane_border(pane, root, "right", all_geoms)

			assert.are.equal(chars.vertical_left, border[constants.BORDER_BOTTOM_LEFT])
		end)
	end)
end)
