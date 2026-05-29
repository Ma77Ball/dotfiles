-- Centralised Mason install list for non-LSP tooling (debug adapters, etc.).
-- LSP servers themselves are handled by mason-lspconfig (see lsp.lua).
return {
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "williamboman/mason.nvim" },
    config = function()
      require("mason-tool-installer").setup({
        ensure_installed = {
          -- Java
          "java-debug-adapter",
          "java-test",
          -- Python
          "debugpy",
          -- TypeScript / JavaScript
          "js-debug-adapter",
        },
      })
    end,
  },
}
