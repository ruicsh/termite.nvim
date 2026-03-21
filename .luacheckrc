std = "luajit"
globals = { "vim" }

-- Line length is enforced by StyLua (column_width = 120 in .stylua.toml).
-- Disable the luacheck line-length warning to avoid false positives on long
-- doc comments and annotations that StyLua does not reformat.
max_line_length = false

-- Test files also use busted globals (describe, it, assert, etc.)
files["spec/**/*.lua"] = {
	std = "+busted",
	self = false,
}
