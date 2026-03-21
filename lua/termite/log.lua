-- termite.nvim
-- Debug logging utilities.

local config = require("termite.config")

local M = {}

-- Debug logging {{-

M.dlog = function(...)
	if not config.values.debug then
		return
	end

	local args = { ... }
	for _, v in ipairs(args) do
		print(vim.inspect(v))
	end
end

-- }}

return M

-- vim: foldmethod=marker:foldmarker={{{,}}}:foldlevel=0
