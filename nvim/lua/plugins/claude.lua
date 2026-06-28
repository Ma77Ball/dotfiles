-- claudecode.nvim: runs the `claude` CLI in a native in-nvim terminal split.
-- Window nav (including the Claude split) is via smart-splits.nvim (<C-h/j/k/l>).
return {
  {
    "coder/claudecode.nvim",
    config = function()
      require("claudecode").setup({
        -- start every session in `auto` permission mode (all entry points)
        terminal_cmd = "claude --permission-mode auto",
        terminal = {
          provider = "native",
          split_width_percentage = 0.30,
        },
      })

      -- Terminal-mode keys inside the Claude prompt (this buffer only):
      --   C-q -> hide the Claude window (session kept); C-x -> jump back to code
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
      -- accept/reject a proposed edit diff
      { "<leader>cy", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Claude: accept diff" },
      { "<leader>cx", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Claude: reject diff" },
    },
  },
}
