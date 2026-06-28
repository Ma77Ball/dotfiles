-- Toggle a terminal from any buffer with <C-\>; run code, then hide it again.
return {
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    -- Load at startup so the <C-\> open_mapping (registered inside config below)
    -- always exists. Without this, lazy.nvim treats the plugin as lazy, never
    -- loads it, and <C-\> silently does nothing.
    lazy = false,
    config = function()
      require("toggleterm").setup({
        open_mapping = [[<c-\>]], -- Ctrl-\ toggles the terminal from any tab
        direction = "float",      -- "float" | "horizontal" | "vertical"
        float_opts = { border = "curved" },
        start_in_insert = true,
      })

      -- Make <C-\> also toggle from inside the terminal, and ease window nav.
      vim.api.nvim_create_autocmd("TermOpen", {
        pattern = "term://*toggleterm#*",
        callback = function()
          local opts = { buffer = 0 }
          vim.keymap.set("t", "<C-\\>", [[<Cmd>ToggleTerm<CR>]], opts)
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
