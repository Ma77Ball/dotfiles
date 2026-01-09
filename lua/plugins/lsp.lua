return {
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "williamboman/mason.nvim",
      "mason-org/mason-lspconfig.nvim",
    },
    config = function()
      require("mason").setup()

      -- mason-lspconfig v2+ can auto-enable servers you install
      require("mason-lspconfig").setup({
        ensure_installed = {
          "lua_ls",
          "pyright",
          "html",
          "jdtls",
        },
        -- automatic_enable = true, -- (this is the default)
      }) -- :contentReference[oaicite:1]{index=1}

      -- Configure servers with the *new* API (no require("lspconfig")!)
      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            diagnostics = { globals = { "vim" } },
          },
        },
      }) -- :contentReference[oaicite:2]{index=2}

      vim.lsp.config("pyright", {})
      vim.lsp.config("html", {})
      vim.lsp.config("metals", {})
      vim.lsp.config("jdtls", {})

      -- If you turned off mason-lspconfig auto-enable, enable explicitly:
      -- vim.lsp.enable({ "lua_ls", "pyright", "html", "metals", "jdtls" })
      -- :contentReference[oaicite:3]{index=3}
    end,
  },
}

