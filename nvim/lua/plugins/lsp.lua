return {
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "williamboman/mason.nvim",
      "mason-org/mason-lspconfig.nvim",
    },
    config = function()
      -- Neovim 0.11 ships with virtual_text OFF by default, so LSP diagnostics
      -- (e.g. ts_ls's "'}' expected" syntax errors) only appear as a faint gutter
      -- sign + underline -- easy to miss, and invisible when the error lands on a
      -- blank line at EOF. Turn the inline message back on so these errors are
      -- actually readable in the buffer.
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

      -- Advertise capabilities for nvim-cmp
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
        -- jdtls needs special handling (per-project workspace, debug/test bundles, Java 21+
        -- runtime), so let nvim-jdtls launch it instead of mason-lspconfig auto-enabling it.
        automatic_enable = {
          exclude = { "jdtls" },
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

