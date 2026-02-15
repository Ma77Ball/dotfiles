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
      local mason_lspconfig = require("mason-lspconfig")
      local lspconfig = require("lspconfig")
      local cmp_nvim_lsp = require("cmp_nvim_lsp")

      -- Advertise capabilities for nvim-cmp
      local capabilities = cmp_nvim_lsp.default_capabilities()

      mason_lspconfig.setup({
        ensure_installed = {
          "lua_ls",
          "pyright",
          "ruff", -- Python linting/formatting
          "html",
          "jdtls",
        },
        handlers = {
          -- Default handler for installed servers
          function(server_name)
            lspconfig[server_name].setup({
              capabilities = capabilities,
            })
          end,

          -- Targeted overrides for specific servers
          ["lua_ls"] = function()
            lspconfig.lua_ls.setup({
              capabilities = capabilities,
              settings = {
                Lua = {
                  diagnostics = { globals = { "vim" } },
                },
              },
            })
          end,

          ["pyright"] = function()
             lspconfig.pyright.setup({
              capabilities = capabilities,
               settings = {
                 python = {
                   analysis = {
                     typeCheckingMode = "basic", -- or "strict"
                     autoSearchPaths = true,
                     useLibraryCodeForTypes = true,
                   }
                 }
               }
             })
          end,

          -- Ruff config (mostly default is good for now)
          ["ruff"] = function()
               lspconfig.ruff.setup({
                  -- Disable hover in favor of Pyright
                  on_attach = function(client, _)
                    client.server_capabilities.hoverProvider = false
                  end
               })
          end,
        },
      })

    end,
  },
}

