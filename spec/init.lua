-- Bootstrap init for running tests in CI
-- Adds plenary.nvim and plugin to runtimepath

local test_root = vim.fn.getcwd()
vim.opt.rtp:prepend(test_root)

-- Add plenary.nvim (cloned by CI to vendor/plenary.nvim)
local plenary_path = test_root .. "/vendor/plenary.nvim"
if vim.fn.isdirectory(plenary_path) == 1 then
	vim.opt.rtp:prepend(plenary_path)
end

-- Load plenary's plugin file to make PlenaryBustedDirectory available
vim.cmd.runtime({ "plugin/plenary.vim", bang = true })
