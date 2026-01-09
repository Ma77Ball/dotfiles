vim.g.mapleader = " "
-- file explorer (neo-tree) remap
vim.keymap.set("n", "<leader>pv", function()
  vim.cmd("Neotree toggle")
end)
