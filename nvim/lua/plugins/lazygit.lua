-- Lazygit in a floating terminal (<leader>gg), reusing toggleterm.nvim.
local lazygit_term
local lazygit_dir

local function toggle_lazygit()
  -- recreate the cached terminal if its buffer was wiped or the cwd changed
  -- (toggleterm pins a terminal's dir at creation and won't follow :cd)
  local dir = vim.fn.getcwd()
  local valid = lazygit_term
    and lazygit_term.bufnr
    and vim.api.nvim_buf_is_valid(lazygit_term.bufnr)
  if not valid or lazygit_dir ~= dir then
    if lazygit_term then
      pcall(function() lazygit_term:shutdown() end)
    end
    local Terminal = require("toggleterm.terminal").Terminal
    lazygit_dir = dir
    lazygit_term = Terminal:new({
      cmd = "lazygit",
      dir = dir,     -- pin to the current cwd (use "git_dir" for the repo root)
      hidden = true, -- not part of the numbered toggleterm set; only <leader>gg opens it
      direction = "float",
      float_opts = { border = "curved" },
      on_open = function(term)
        vim.cmd("startinsert!")
        -- drop the toggleterm <Esc>/<C-h/j/k/l> maps so lazygit gets those keys
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
