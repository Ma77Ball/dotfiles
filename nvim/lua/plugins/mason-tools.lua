-- mason-tool-installer: auto-installs non-LSP Mason tools (debug adapters); LSP servers are in lsp.lua.
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
