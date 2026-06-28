-- Lazygit in a floating terminal, opened with <leader>gg.
-- Reuses the toggleterm.nvim that toggleterm.lua already configures, so there's
-- no extra plugin to manage; this spec only adds the keymap and a cached
-- terminal. Complements the diffview viewers (<leader>gd/<leader>gu) with an
-- actual stage/commit/push UI.
local lazygit_term

local function toggle_lazygit()
  if not lazygit_term then
    local Terminal = require("toggleterm.terminal").Terminal
    lazygit_term = Terminal:new({
      cmd = "lazygit",
      hidden = true, -- not part of the numbered toggleterm set; only <leader>gg opens it
      direction = "float",
      float_opts = { border = "curved" },
      on_open = function(term)
        vim.cmd("startinsert!")
        -- The global TermOpen autocmd in toggleterm.lua maps <Esc> and
        -- <C-h/j/k/l> to exit terminal mode (for back/cancel and window nav).
        -- Lazygit relies on Esc for back/cancel and on <C-h/j/k/l> to
        -- navigate/scroll its panels, so drop those buffer-local maps and let
        -- the keys reach lazygit. Scheduled so it runs after the autocmd
        -- installs them.
        vim.schedule(function()
          for _, key in ipairs({ "<Esc>", "<C-h>", "<C-j>", "<C-k>", "<C-l>" }) do
            pcall(vim.keymap.del, "t", key, { buffer = term.bufnr })
          end
        end)
      end,
    })
  end
  lazygit_term:toggle()
end

return {
  {
    "akinsho/toggleterm.nvim",
    keys = {
      { "<leader>gg", toggle_lazygit, desc = "Lazygit (float)" },
    },
  },
}
