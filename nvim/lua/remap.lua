vim.g.mapleader = " "

vim.keymap.set("i", "jj", "<Esc>", { desc = "Exit insert mode" })
vim.keymap.set("n", "<leader>pv", function()
  vim.cmd("Neotree filesystem toggle")
end, { desc = "Neo-tree toggle" })

vim.keymap.set("n", "<leader>pf", function()
  vim.cmd("Neotree filesystem reveal")
end, { desc = "Neo-tree reveal current file" })

-- Run the current file (python/lua), else report no runner.
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

-- Remap jump-forward to Ctrl-Enter; use Tab/Shift-Tab to indent/outdent.
vim.keymap.set("n", "<C-CR>", "<C-i>", { desc = "Jump forward (jumplist)" })
vim.keymap.set("n", "<Tab>", ">>", { desc = "Indent line" })
vim.keymap.set("n", "<S-Tab>", "<<", { desc = "Outdent line" })
vim.keymap.set("x", "<Tab>", ">gv", { desc = "Indent selection" })
vim.keymap.set("x", "<S-Tab>", "<gv", { desc = "Outdent selection" })

-- Diagnostic keymaps
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, { desc = 'Go to previous diagnostic message' })
vim.keymap.set('n', ']d', vim.diagnostic.goto_next, { desc = 'Go to next diagnostic message' })
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Open floating diagnostic message' })
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostics list' })

vim.keymap.set('n', '<leader>gp', '<cmd>!gh pr view --web<cr>', { desc = 'Git: open PR in browser' })

vim.keymap.set('n', '<leader>w', function()
  vim.wo.wrap = not vim.wo.wrap
  print("wrap " .. (vim.wo.wrap and "on" or "off"))
end, { desc = 'Toggle line wrap' })
