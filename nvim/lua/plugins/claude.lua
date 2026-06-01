-- Claude Code integration: runs the `claude` CLI in a NATIVE in-nvim terminal split
-- (the original setup). The editor-wide lag this used to cause was NOT nvim's
-- rendering -- it was the laptop sitting in the `powersave` CPU governor on AC, so
-- cores idled at 605 MHz and were slow to boost for claude's bursty TUI redraws.
-- With the performance governor (or a "Performance" power profile) the in-nvim
-- terminal is responsive, so Claude lives back inside nvim.
--
-- Window navigation between splits (including the Claude window) is via
-- smart-splits.nvim (<C-h/j/k/l>). Terminal-mode hide/jump keys are in TermOpen below.
return {
  {
    "coder/claudecode.nvim",
    config = function()
      require("claudecode").setup({
        terminal = {
          provider = "native",
          split_width_percentage = 0.30,
        },
      })

      -- Fast escape from *inside* the Claude prompt (terminal-mode, this buffer only):
      --   Ctrl-q -> leave prompt + hide the Claude window (toggle closed; session kept)
      --   Ctrl-x -> leave prompt + jump back to your code window (Claude stays open)
      -- Re-open the hidden session with <leader>cm -- the native provider keeps the
      -- job alive while hidden, so it's the same conversation.
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
