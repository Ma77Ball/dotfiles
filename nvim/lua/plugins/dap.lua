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
      "Weissle/persistent-breakpoints.nvim",
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

      -- Persist breakpoints to disk per-project and reload them on file open.
      -- Set breakpoints via its API (the <leader>b/<leader>B maps below) so they
      -- get saved; a session restart or nvim reopen restores them.
      require("persistent-breakpoints").setup({
        load_breakpoints_event = { "BufReadPost" },
      })

      -- auto-open the UI on session start; close manually with <F7>
      -- (no auto-close: it wipes console output and reflows neo-tree)
      dap.listeners.before.attach.dapui_config = function() dapui.open() end
      dap.listeners.before.launch.dapui_config = function() dapui.open() end

      -- breakpoint/stopped signs
      vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticSignError" })
      vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticSignWarn" })

      -- debug keymaps (function keys avoid the <leader>d multicursor mappings)
      vim.keymap.set("n", "<F5>", dap.continue, { desc = "Debug: start/continue" })
      -- Stop/terminate. Terminals report Shift-F5 as either <S-F5> or <F17>
      -- (terminfo kf17 == shifted F5), so bind both to be safe.
      vim.keymap.set("n", "<S-F5>", dap.terminate, { desc = "Debug: stop/terminate" })
      vim.keymap.set("n", "<F17>", dap.terminate, { desc = "Debug: stop/terminate (Shift-F5)" })
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
      -- Route breakpoint set/clear through persistent-breakpoints so they're saved.
      local pb = require("persistent-breakpoints.api")
      vim.keymap.set("n", "<leader>b", pb.toggle_breakpoint, { desc = "Debug: toggle breakpoint (persisted)" })
      vim.keymap.set("n", "<leader>B", pb.set_conditional_breakpoint, { desc = "Debug: conditional breakpoint (persisted)" })
      vim.keymap.set("n", "<leader>bc", pb.clear_all_breakpoints, { desc = "Debug: clear all breakpoints" })

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

      -- C/C++ debugging via cpptools (installed by Mason) + gdb.
      -- Launch recompiles a debug build (-g -O0) into /tmp, mirroring the
      -- <leader>r run convention, so <F5> just works with no manual build.
      dap.adapters.cppdbg = {
        id = "cppdbg",
        type = "executable",
        command = vim.fn.stdpath("data")
          .. "/mason/packages/cpptools/extension/debugAdapters/bin/OpenDebugAD7",
      }
      local cpp_cfg = {
        {
          name = "Launch current file (build -g)",
          type = "cppdbg",
          request = "launch",
          program = function()
            local src = vim.fn.expand("%")
            local bin = "/tmp/" .. vim.fn.expand("%:t:r") .. "_dbg"
            vim.fn.system({ "g++", "-std=c++20", "-g", "-O0", "-Wall", src, "-o", bin })
            if vim.v.shell_error ~= 0 then
              error("compile failed")
            end
            return bin
          end,
          cwd = "${workspaceFolder}",
          stopAtEntry = false,
          MIMode = "gdb",
          miDebuggerPath = "/usr/bin/gdb",
          setupCommands = {
            { text = "-enable-pretty-printing", ignoreFailures = true },
          },
        },
      }
      dap.configurations.cpp = cpp_cfg
      dap.configurations.c = cpp_cfg
    end,
  },
}
