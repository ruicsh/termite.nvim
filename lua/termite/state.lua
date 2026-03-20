-- termite.nvim
-- Shared mutable state.

return {
	terminals = {}, -- Ordered list of terminal entries: { buf, win, config }.
	visible = false, -- Whether the terminal panel is currently shown.
	maximized_idx = nil, -- Index of maximized terminal, or nil if none.
	last_editor_winnr = nil, -- Window to return to when focusing editor.
	last_focused_idx = nil, -- Index of the most recently focused terminal.
	next_count = 1, -- Incrementing counter for unique terminal ids.
}
