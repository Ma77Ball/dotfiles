-- smart-splits.nvim: <C-h/j/k/l> navigates between nvim splits.
-- Multiplexer integration is intentionally left off: we move between zellij
-- panes with zellij's own keys, not <C-hjkl>. In smart-splits v2 "off" is simply
-- leaving `mux.backend` unset (the default), so nothing needs to be configured.
-- The old `multiplexer_integration = false` option was renamed to `mux.backend`
-- and now warns on startup, so it has been removed.
return {
  {
    "mrjones2014/smart-splits.nvim",
    lazy = false,
    keys = {
      { "<C-h>", function() require("smart-splits").move_cursor_left() end, desc = "Move to split/pane left" },
      { "<C-j>", function() require("smart-splits").move_cursor_down() end, desc = "Move to split/pane below" },
      { "<C-k>", function() require("smart-splits").move_cursor_up() end, desc = "Move to split/pane above" },
      { "<C-l>", function() require("smart-splits").move_cursor_right() end, desc = "Move to split/pane right" },
    },
  },
}
