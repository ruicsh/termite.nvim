-- termite.nvim
-- Shared mutable state.

return {
	terminals = {}, -- Ordered list of terminal entries: { buf, win, config }.
	visible = false, -- Whether the terminal panel is currently shown.
	maximized_idx = nil, -- Index of maximized terminal, or nil if none (stack layout).
	maximized_term_id = nil, -- ID of maximized terminal, or nil if none (tmux layout).
	last_editor_winnr = nil, -- Window to return to when focusing editor.
	last_focused_idx = nil, -- Index of the most recently focused terminal (stack layout).
	last_focused_term_id = nil, -- ID of most recently focused terminal (tmux layout).
	next_count = 1, -- Incrementing counter for unique terminal display ids.
	next_term_id = 1, -- Incrementing counter for unique terminal IDs (tmux layout).
	pane_tree = nil, -- Root node of pane tree for tmux layout (tree of leaves and splits).
	-- Pane tree node types:
	--   Leaf: { type = "leaf", term_id = <number> }
	--   Split: { type = "split", dir = "h"|"v", ratio = 0.5, children = { node, node } }
}
