-- mason-tool-installer: auto-installs non-LSP Mason tools (debug adapters); LSP servers are in lsp.lua.
return {
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "williamboman/mason.nvim" },
    config = function()
      -- Ensure Mason's registry is initialized before the tool-installer runs.
      -- mason.setup() otherwise lives in lsp.lua, which only loads on
      -- BufReadPre/BufNewFile -- so starting Nvim on a directory (`nvim .`)
      -- would leave the registry uninitialized and the installer would fail
      -- with "Cannot find package ...". setup() is idempotent, so calling it
      -- here as well is safe.
      require("mason").setup()

      require("mason-tool-installer").setup({
        ensure_installed = {
          -- Java
          "java-debug-adapter",
          "java-test",
          -- Python
          "debugpy",
          -- TypeScript / JavaScript
          "js-debug-adapter",
          -- C / C++
          "clang-format", -- used by conform.nvim for c/cpp
        },
      })
    end,
  },
}
