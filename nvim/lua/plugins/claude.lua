-- Claude Code integration: runs the `claude` CLI in a wezterm split pane beside nvim
-- and connects it back to the editor (selections as context, edits shown as native
-- diffs). The pane is managed by a custom provider (lua/claude_wezterm.lua) so it
-- behaves like the old in-nvim window -- toggle, hide, jump back -- but as a separate
-- process, which keeps claude's redraw-heavy TUI off nvim's main loop (no input lag).
--
-- Window navigation + the Ctrl-x / Ctrl-q commands live on the wezterm side
-- (smart-splits.nvim + ~/.config/wezterm/wezterm.lua), since claude is a wezterm pane,
-- not an nvim terminal buffer:
--   <C-h/j/k/l>  move between nvim splits AND the claude pane, seamlessly
--   Ctrl-x       (in claude) jump back to code, leave claude open beside it
--   Ctrl-q       (in claude) hide claude + jump back to code (session kept alive)
return {
  {
    "coder/claudecode.nvim",
    config = function()
      require("claudecode").setup({
        terminal = {
          provider = require("claude_wezterm"),
          split_width_percentage = 0.40,
        },
      })
    end,
    keys = {
      { "<leader>cc", "<cmd>ClaudeCode<cr>", desc = "Claude: toggle show/hide" },
      { "<leader>cm", "<cmd>ClaudeCodeFocus<cr>", desc = "Claude: open / jump to window" },
      { "<leader>cs", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Claude: send selection" },
      { "<leader>cb", "<cmd>ClaudeCodeAdd %<cr>", desc = "Claude: add current file" },
      -- When Claude proposes an edit (shown as a diff):
      { "<leader>cy", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Claude: accept diff" },
      { "<leader>cx", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Claude: reject diff" },
    },
  },
}
