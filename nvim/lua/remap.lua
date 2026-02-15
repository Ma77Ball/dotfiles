vim.g.mapleader = " "
-- file explorer (neo-tree) remap
vim.keymap.set("n", "<leader>pv", function()
  vim.cmd("Neotree toggle")
end)

-- Run current file
vim.keymap.set("n", "<leader>r", function()
  local filetype = vim.bo.filetype
  if filetype == "python" then
    vim.cmd("write")
    vim.cmd("!python3 %")
  elseif filetype == "lua" then
    vim.cmd("write")
    vim.cmd("source %")
  else
    print("No runner for filetype: " .. filetype)
  end
end)

-- Diagnostic keymaps
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, { desc = 'Go to previous diagnostic message' })
vim.keymap.set('n', ']d', vim.diagnostic.goto_next, { desc = 'Go to next diagnostic message' })
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Open floating diagnostic message' })
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostics list' })
