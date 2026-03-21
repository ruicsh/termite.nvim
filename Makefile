# termite.nvim Makefile
# Stacking float terminal manager for Neovim

.PHONY: test test-file lint format help

# Default target
.DEFAULT_GOAL := help

# Test all spec files
test:
	@nvim --headless --noplugin -u spec/init.lua -c "PlenaryBustedDirectory spec/ {minimal_init = 'spec/minimal_init.vim'}"

# Test a single file (usage: make test-file FILE=spec/config_spec.lua)
test-file:
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make test-file FILE=spec/config_spec.lua"; \
		exit 1; \
	fi
	@nvim --headless -c "PlenaryBustedFile $(FILE)"

# Lint Lua code with luacheck
lint:
	@luacheck lua/ plugin/ spec/

# Format Lua code with stylua
format:
	@stylua lua/ plugin/ spec/

# Run all checks (format, lint, test)
check: format lint test

# Display help
help:
	@echo "termite.nvim - Available targets:"
	@echo ""
	@echo "  make test              Run all tests"
	@echo "  make test-file FILE=   Run a specific test file"
	@echo "  make lint              Run luacheck linter"
	@echo "  make format            Format code with stylua"
	@echo "  make check             Run format, lint, and test"
	@echo "  make help              Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make test-file FILE=spec/config_spec.lua"
	@echo "  make check"
