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

      dapui.setup()
      require("nvim-dap-virtual-text").setup()

      -- Auto-open the debug UI when a session starts. Do NOT auto-close on
      -- finish: that wipes the console output instantly and the window reflow
      -- blows up the neo-tree panel. Close it yourself with <F7> when done.
      dap.listeners.before.attach.dapui_config = function() dapui.open() end
      dap.listeners.before.launch.dapui_config = function() dapui.open() end

      -- Breakpoint sign tweaks
      vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticSignError" })
      vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticSignWarn" })

      -- Debug keymaps (function keys avoid clashing with the <leader>d
      -- multiple-cursors mappings).
      vim.keymap.set("n", "<F5>", dap.continue, { desc = "Debug: start/continue" })
      vim.keymap.set("n", "<F10>", dap.step_over, { desc = "Debug: step over" })
      vim.keymap.set("n", "<F11>", dap.step_into, { desc = "Debug: step into" })
      vim.keymap.set("n", "<F12>", dap.step_out, { desc = "Debug: step out" })
      vim.keymap.set("n", "<F7>", dapui.toggle, { desc = "Debug: toggle UI" })
      vim.keymap.set("n", "<leader>b", dap.toggle_breakpoint, { desc = "Debug: toggle breakpoint" })
      vim.keymap.set("n", "<leader>B", function()
        dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
      end, { desc = "Debug: conditional breakpoint" })

      -- JS / TS node debugging via js-debug-adapter (installed by Mason).
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
