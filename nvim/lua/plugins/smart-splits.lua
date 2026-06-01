-- Seamless window navigation: <C-h/j/k/l> moves between nvim splits. Claude now
-- runs as a native in-nvim terminal (see plugins/claude.lua), and the terminal is
-- Ghostty -- which is not a CLI multiplexer -- so there are no external panes to
-- cross into. Multiplexer integration is therefore disabled; these keys move
-- between nvim splits only (the Claude window included, since it's a real split).
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
