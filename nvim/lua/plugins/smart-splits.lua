-- Seamless window navigation: <C-h/j/k/l> moves between nvim splits, and when you
-- hit the edge it crosses straight into the adjacent wezterm pane (e.g. the Claude
-- pane) via `wezterm cli activate-pane-direction`. The reverse direction (jumping
-- from the Claude pane back into nvim) is handled on the wezterm side -- see
-- ~/.config/wezterm/wezterm.lua. Together they make the Claude split feel native.
return {
  {
    "mrjones2014/smart-splits.nvim",
    lazy = false,
    opts = {
      multiplexer_integration = "wezterm",
    },
    keys = {
      { "<C-h>", function() require("smart-splits").move_cursor_left() end, desc = "Move to split/pane left" },
      { "<C-j>", function() require("smart-splits").move_cursor_down() end, desc = "Move to split/pane below" },
      { "<C-k>", function() require("smart-splits").move_cursor_up() end, desc = "Move to split/pane above" },
      { "<C-l>", function() require("smart-splits").move_cursor_right() end, desc = "Move to split/pane right" },
    },
  },
}
