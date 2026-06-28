-- nvim-lspconfig + Mason: install and configure LSP servers (lua/python/ts/html).
-- jdtls is excluded here; nvim-jdtls starts it (ftplugin/java.lua).
return {
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "williamboman/mason.nvim",
      "mason-org/mason-lspconfig.nvim",
    },
    config = function()
      -- Nvim 0.11 hides diagnostics inline by default; turn virtual_text back on
      vim.diagnostic.config({
        virtual_text = {
          spacing = 2,
          prefix = "●",
          source = "if_many",
        },
        signs = true,
        underline = true,
        update_in_insert = false, -- don't churn diagnostics on every keystroke
        severity_sort = true,
        float = {
          border = "rounded",
          source = true,
        },
      })

      require("mason").setup()
      local mason_lspconfig = require("mason-lspconfig")
      local lspconfig = require("lspconfig")
      local cmp_nvim_lsp = require("cmp_nvim_lsp")

      -- advertise nvim-cmp completion capabilities to servers
      local capabilities = cmp_nvim_lsp.default_capabilities()

      mason_lspconfig.setup({
        ensure_installed = {
          "lua_ls",
          "pyright",
          "ruff", -- Python linting/formatting
          "ts_ls", -- TypeScript / JavaScript
          "html",
          "jdtls", -- installed by Mason, but started/configured by nvim-jdtls (see ftplugin/java.lua)
        },
        -- let nvim-jdtls launch jdtls instead of auto-enabling it here
        automatic_enable = {
          exclude = { "jdtls" },
        },
        handlers = {
          -- default handler for installed servers
          function(server_name)
            lspconfig[server_name].setup({
              capabilities = capabilities,
            })
          end,

          -- per-server overrides
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

