-- smart-splits.nvim: <C-h/j/k/l> navigates between nvim splits.
-- Multiplexer integration is off (Ghostty has no panes to cross into).
return {
  {
    "mrjones2014/smart-splits.nvim",
    lazy = false,
    opts = {
      multiplexer_integration = false,
    },
    keys = {
      { "<C-h>", function() require("smart-splits").move_cursor_left() end, desc = "Move to split/pane left" },
      { "<C-j>", function() require("smart-splits").move_cursor_down() end, desc = "Move to split/pane below" },
      { "<C-k>", function() require("smart-splits").move_cursor_up() end, desc = "Move to split/pane above" },
      { "<C-l>", function() require("smart-splits").move_cursor_right() end, desc = "Move to split/pane right" },
    },
  },
}
