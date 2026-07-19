-- Toggle a terminal from any buffer with <C-\>; run code, then hide it again.
return {
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    -- load at startup so the <C-\> open_mapping always exists
    lazy = false,
    config = function()
      require("toggleterm").setup({
        -- open_mapping is set manually below with `nowait` -- <C-\> is a prefix
        -- of Neovim's built-in CTRL-\ CTRL-N, so a plain mapping makes Neovim
        -- wait 'timeoutlen' for a continuation (the "press twice" symptom).
        direction = "float",      -- "float" | "horizontal" | "vertical"
        float_opts = { border = "curved" },
        start_in_insert = true,
      })

      -- Ctrl-\ opens the terminal in a single press from a normal/insert buffer.
      -- nowait avoids the wait on Neovim's built-in CTRL-\ CTRL-N prefix (the
      -- "press twice" symptom). NOT set in terminal mode globally -- that would
      -- also hijack <C-\> inside other terminals (e.g. the remote-nvim client),
      -- breaking <leader>sh.
      for _, mode in ipairs({ "n", "i" }) do
        vim.keymap.set(mode, "<C-\\>", [[<Cmd>ToggleTerm<CR>]],
          { nowait = true, silent = true, desc = "Toggle floating terminal" })
      end

      -- Inside a toggleterm terminal ONLY (buffer-local, so it never touches
      -- other terminals): <C-\> toggles it away, <Esc> exits, <C-h/j/k/l> move.
      vim.api.nvim_create_autocmd("TermOpen", {
        pattern = "term://*toggleterm#*",
        callback = function()
          local opts = { buffer = 0 }
          vim.keymap.set("t", "<C-\\>", [[<Cmd>ToggleTerm<CR>]],
            vim.tbl_extend("force", opts, { nowait = true }))
          vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], opts)
          vim.keymap.set("t", "<C-h>", [[<C-\><C-n><C-w>h]], opts)
          vim.keymap.set("t", "<C-j>", [[<C-\><C-n><C-w>j]], opts)
          vim.keymap.set("t", "<C-k>", [[<C-\><C-n><C-w>k]], opts)
          vim.keymap.set("t", "<C-l>", [[<C-\><C-n><C-w>l]], opts)
        end,
      })
    end,
  },
}
