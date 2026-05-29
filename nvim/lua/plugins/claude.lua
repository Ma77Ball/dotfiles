-- Claude Code integration: runs the `claude` CLI inside nvim and connects it
-- back to the editor (selections as context, edits shown as native diffs).
return {
  {
    "coder/claudecode.nvim",
    config = function()
      require("claudecode").setup({
        -- Use the built-in terminal (no extra deps like snacks.nvim needed).
        terminal = { provider = "native" },
      })

      -- Fast escape from *inside* the Claude prompt.
      -- Leader maps don't fire here: the terminal is in insert mode, so they'd
      -- just get typed into Claude. These are terminal-mode maps, scoped to the
      -- Claude terminal buffer only (so other :terminal sessions are untouched).
      --   Ctrl-q -> leave prompt + hide the Claude window (toggle closed)
      --   Ctrl-x -> leave prompt + jump back to your code window (Claude stays)
      --   Ctrl-\ Ctrl-n still works as the built-in fallback.
      vim.api.nvim_create_autocmd("TermOpen", {
        callback = function(args)
          if not vim.api.nvim_buf_get_name(args.buf):match("claude") then
            return
          end
          local opts = { buffer = args.buf, silent = true }
          vim.keymap.set("t", "<C-q>", [[<cmd>ClaudeCode<cr>]],
            vim.tbl_extend("force", opts, { desc = "Claude: exit prompt + hide" }))
          vim.keymap.set("t", "<C-x>", [[<C-\><C-n><C-w>p]],
            vim.tbl_extend("force", opts, { desc = "Claude: exit prompt + jump to code" }))
        end,
      })
    end,
    keys = {
      { "<leader>cc", "<cmd>ClaudeCode<cr>", desc = "Claude: toggle" },
      { "<leader>cm", "<cmd>ClaudeCodeFocus<cr>", desc = "Claude: focus window" },
      { "<leader>cs", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Claude: send selection" },
      { "<leader>cb", "<cmd>ClaudeCodeAdd %<cr>", desc = "Claude: add current file" },
      -- When Claude proposes an edit (shown as a diff):
      { "<leader>cy", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Claude: accept diff" },
      { "<leader>cx", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Claude: reject diff" },
    },
  },
}
