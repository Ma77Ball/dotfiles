-- nvim-dap-python: Python debugging via debugpy (LSP is pyright + ruff, see lsp.lua).
return {
  {
    "mfussenegger/nvim-dap-python",
    ft = "python",
    dependencies = { "mfussenegger/nvim-dap" },
    config = function()
      -- Use Mason's debugpy venv Python, else fall back to python3.
      local debugpy = vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/bin/python"
      if vim.fn.executable(debugpy) == 1 then
        require("dap-python").setup(debugpy)
      else
        require("dap-python").setup("python3")
      end

      vim.keymap.set("n", "<leader>tn", function()
        require("dap-python").test_method()
      end, { desc = "Python: debug nearest test" })
      vim.keymap.set("n", "<leader>tc", function()
        require("dap-python").test_class()
      end, { desc = "Python: debug test class" })
    end,
  },
}
