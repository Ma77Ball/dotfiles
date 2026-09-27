-- claudecode.nvim: runs the `claude` CLI in a native in-nvim terminal split.
-- Window nav (including the Claude split) is via smart-splits.nvim (<C-h/j/k/l>).
return {
  {
    "coder/claudecode.nvim",
    config = function()
      require("claudecode").setup({
        -- start every session in `auto` permission mode with Opus 4.8 as the default model.
        -- `--continue` resumes the most recent session in this dir on launch, so reopening
        -- nvim reattaches instead of leaving a leftover "background session" prompt.
        terminal_cmd = "claude --continue --permission-mode auto --model claude-opus-4-8", -- do not change unless you ask admin should use opus 4.8
        terminal = {
          provider = "native",
          split_width_percentage = 0.30,
        },
      })

      -- Seed the default account (personal) and enable <leader>ca switching.
      -- See lua/claude_accounts.lua for how CLAUDE_CONFIG_DIR is swapped per-launch.
      require("claude_accounts").apply_default()

      -- Terminal-mode keys inside the Claude prompt (this buffer only):
      --   C-q -> hide the Claude window (session kept); C-x -> jump back to code
      vim.api.nvim_create_autocmd("TermOpen", {
        callback = function(args)
          if not vim.api.nvim_buf_get_name(args.buf):match("claude") then
            return
          end
          local opts = { buffer = args.buf, silent = true }
          vim.keymap.set("t", "<C-q>", [[<cmd>ClaudeCode<cr>]],
            vim.tbl_extend("force", opts, { desc = "Claude: exit prompt + hide" }))
          vim.keymap.set("t", "<C-x>", [[<C-\><C-n><C-w>p]],
            vim.tbl_extend("force", opts, { desc = "Claude: exit prompt + jump to code" }))
        end,
      })

      -- ------------------------------------------------------------------
      -- Scroll the Claude window with the mouse wheel even when it is NOT
      -- focused.
      --
      -- `claude` runs as a full-screen TUI: it owns the screen and handles
      -- the wheel itself, and Neovim only forwards wheel events to a terminal
      -- job when that terminal is the *current* window. There is no Neovim
      -- scrollback to scroll either, so by default you can only scroll Claude
      -- after focusing it. These maps intercept the wheel and, when the
      -- pointer is over the Claude terminal, send it straight to that job (SGR
      -- mouse: 64 = wheel up, 65 = wheel down) so it scrolls in place with no
      -- focus change. Over any other window the wheel behaves normally.
      -- Terminal mode is left unmapped so a focused Claude still gets the
      -- wheel the usual way. Requires `mouse=a` (set in lua/options.lua).
      -- ------------------------------------------------------------------
      local WHEEL_REPEAT = 3 -- wheel ticks sent per notch (raise = faster)

      local function claude_term_under_mouse()
        local mp = vim.fn.getmousepos()
        local win = mp.winid
        if win == 0 or not vim.api.nvim_win_is_valid(win) then
          return nil
        end
        local buf = vim.api.nvim_win_get_buf(win)
        local is_claude = vim.bo[buf].buftype == "terminal"
          and (vim.api.nvim_buf_get_name(buf) or ""):match("claude") ~= nil
        if is_claude then
          return mp, buf
        end
        return nil
      end

      local function claude_wheel(dir)
        local fallback = vim.keycode(dir == "up" and "<ScrollWheelUp>" or "<ScrollWheelDown>")
        local code = dir == "up" and 64 or 65
        return function()
          local mp, buf = claude_term_under_mouse()
          local chan = mp and vim.bo[buf].channel
          if not chan or chan <= 0 then
            -- Not over Claude (or no job): run Neovim's built-in wheel.
            -- Feedkeys with mode "n" is noremap, so this does not recurse.
            vim.api.nvim_feedkeys(fallback, "n", false)
            return
          end
          local col = math.max(mp.wincol, 1)
          local row = math.max(mp.winrow, 1)
          local tick = string.format("\27[<%d;%d;%dM", code, col, row)
          vim.api.nvim_chan_send(chan, tick:rep(WHEEL_REPEAT))
        end
      end

      for _, mode in ipairs({ "n", "i", "v" }) do
        vim.keymap.set(mode, "<ScrollWheelUp>", claude_wheel("up"),
          { silent = true, desc = "Wheel: scroll Claude even when unfocused" })
        vim.keymap.set(mode, "<ScrollWheelDown>", claude_wheel("down"),
          { silent = true, desc = "Wheel: scroll Claude even when unfocused" })
      end
    end,
    keys = {
      { "<leader>cc", "<cmd>ClaudeCode<cr>", desc = "Claude: toggle" },
      { "<leader>cm", "<cmd>ClaudeCodeFocus<cr>", desc = "Claude: focus window" },
      { "<leader>ca", function() require("claude_accounts").pick() end, desc = "Claude: pick account" },
      { "<leader>cs", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Claude: send selection" },
      { "<leader>cb", "<cmd>ClaudeCodeAdd %<cr>", desc = "Claude: add current file" },
      -- accept/reject a proposed edit diff
      { "<leader>cy", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Claude: accept diff" },
      { "<leader>cx", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Claude: reject diff" },
    },
  },
}
