-- Scala support via Metals (LSP + debugging in one). Metals is managed by
-- nvim-metals (bootstrapped through coursier), not Mason/lspconfig.
return {
  {
    "scalameta/nvim-metals",
    ft = { "scala", "sbt" },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "mfussenegger/nvim-dap",
    },
    opts = function()
      local metals = require("metals")
      local config = metals.bare_config()

      -- Match completion capabilities with the rest of the config (nvim-cmp).
      local ok_cmp, cmp_lsp = pcall(require, "cmp_nvim_lsp")
      if ok_cmp then
        config.capabilities = cmp_lsp.default_capabilities()
      end

      config.settings = {
        showImplicitArguments = true,
        excludedPackages = { "akka.actor.typed.javadsl", "com.github.swagger.akka.javadsl" },
      }

      config.on_attach = function(_, bufnr)
        -- Metals provides debugging directly through nvim-dap.
        metals.setup_dap()

        local map = function(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
        end
        map("n", "gd", vim.lsp.buf.definition, "Go to definition")
        map("n", "gi", vim.lsp.buf.implementation, "Go to implementation")
        map("n", "gr", vim.lsp.buf.references, "References")
        map("n", "K", vim.lsp.buf.hover, "Hover docs")
        map("n", "<leader>cr", vim.lsp.buf.rename, "LSP: rename")
        map("n", "<leader>ca", vim.lsp.buf.code_action, "LSP: code action")
        map("n", "<leader>cf", function() vim.lsp.buf.format({ async = true }) end, "LSP: format")
        -- Metals command picker (server-provided commands: build import, etc.)
        map("n", "<leader>mc", function()
          local ok, telescope = pcall(require, "telescope")
          if ok then
            pcall(telescope.load_extension, "metals")
            telescope.extensions.metals.commands()
          else
            require("metals").commands()
          end
        end, "Metals: commands")
      end

      return config
    end,
    config = function(self, metals_config)
      local group = vim.api.nvim_create_augroup("nvim-metals", { clear = true })
      vim.api.nvim_create_autocmd("FileType", {
        pattern = self.ft,
        callback = function()
          require("metals").initialize_or_attach(metals_config)
        end,
        group = group,
      })
    end,
  },
}
