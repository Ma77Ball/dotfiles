-- Debug Adapter Protocol: the shared nvim-dap client, UI, keymaps, and the
-- JS/TS (node) adapter. Language-specific adapters live with their language:
--   * Java   -> jdtls wires itself in (ftplugin/java.lua)
--   * Python -> nvim-dap-python (plugins/python.lua)
return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      { "rcarriga/nvim-dap-ui", dependencies = { "nvim-neotest/nvim-nio" } },
      "theHamsta/nvim-dap-virtual-text",
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")

      -- fixed UI layout: left sidebar (scopes/stacks/watches/breakpoints),
      -- bottom tray (REPL/console)
      dapui.setup({
        layouts = {
          {
            position = "left",
            size = 50,
            elements = {
              { id = "scopes", size = 0.45 },
              { id = "stacks", size = 0.25 },
              { id = "watches", size = 0.15 },
              { id = "breakpoints", size = 0.15 },
            },
          },
          {
            position = "bottom",
            size = 12,
            elements = {
              { id = "repl", size = 0.5 },
              { id = "console", size = 0.5 },
            },
          },
        },
      })
      require("nvim-dap-virtual-text").setup()

      -- auto-open the UI on session start; close manually with <F7>
      -- (no auto-close: it wipes console output and reflows neo-tree)
      dap.listeners.before.attach.dapui_config = function() dapui.open() end
      dap.listeners.before.launch.dapui_config = function() dapui.open() end

      -- breakpoint/stopped signs
      vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticSignError" })
      vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticSignWarn" })

      -- debug keymaps (function keys avoid the <leader>d multicursor mappings)
      vim.keymap.set("n", "<F5>", dap.continue, { desc = "Debug: start/continue" })
      vim.keymap.set("n", "<F10>", dap.step_over, { desc = "Debug: step over" })
      vim.keymap.set("n", "<F11>", dap.step_into, { desc = "Debug: step into" })
      vim.keymap.set("n", "<F12>", dap.step_out, { desc = "Debug: step out" })
      -- <F7>: toggle the UI; reopen forces the configured layout sizes
      vim.keymap.set("n", "<F7>", function()
        local open = false
        for _, w in ipairs(vim.api.nvim_list_wins()) do
          local ft = vim.bo[vim.api.nvim_win_get_buf(w)].filetype
          if ft:find("dapui_") or ft == "dap-repl" then open = true break end
        end
        if open then dapui.close() else dapui.open({ reset = true }) end
      end, { desc = "Debug: toggle UI (force layout sizes on open)" })
      vim.keymap.set("n", "<leader>b", dap.toggle_breakpoint, { desc = "Debug: toggle breakpoint" })
      vim.keymap.set("n", "<leader>B", function()
        dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
      end, { desc = "Debug: conditional breakpoint" })

      -- JS/TS node debugging via js-debug-adapter (installed by Mason)
      local js_debug = vim.fn.stdpath("data")
        .. "/mason/packages/js-debug-adapter/js-debug/src/dapDebugServer.js"
      dap.adapters["pwa-node"] = {
        type = "server",
        host = "localhost",
        port = "${port}",
        executable = {
          command = "node",
          args = { js_debug, "${port}" },
        },
      }
      for _, lang in ipairs({ "javascript", "typescript" }) do
        dap.configurations[lang] = {
          {
            type = "pwa-node",
            request = "launch",
            name = "Launch current file",
            program = "${file}",
            cwd = "${workspaceFolder}",
          },
          {
            type = "pwa-node",
            request = "attach",
            name = "Attach to process",
            processId = require("dap.utils").pick_process,
            cwd = "${workspaceFolder}",
          },
        }
      end
    end,
  },
}
