vim.g.mapleader = " "

vim.keymap.set("i", "jj", "<Esc>", { desc = "Exit insert mode" })

-- Disable the built-in `s` substitute (identical to `cl`), so a mistimed
-- `<leader>s...` chord can't fall through to a destructive edit. Frees the
-- `s` prefix for the remote-SSH mappings (see plugins/remote-nvim.lua).
-- Use `cl`/`S` instead.
vim.keymap.set({ "n", "x" }, "s", "<Nop>", { desc = "disabled (use cl/S)" })
vim.keymap.set("n", "<leader>pv", function()
  vim.cmd("Neotree filesystem toggle")
end, { desc = "Neo-tree toggle" })

vim.keymap.set("n", "<leader>pf", function()
  vim.cmd("Neotree filesystem reveal")
end, { desc = "Neo-tree reveal current file" })

-- Run the current file (python/lua/cpp), else report no runner.
vim.keymap.set("n", "<leader>r", function()
  local filetype = vim.bo.filetype
  if filetype == "python" then
    vim.cmd("write")
    vim.cmd("!python3 %")
  elseif filetype == "lua" then
    vim.cmd("write")
    vim.cmd("source %")
  elseif filetype == "cpp" or filetype == "c" then
    vim.cmd("write")
    local compiler = filetype == "cpp" and "g++ -std=c++20" or "gcc -std=c17"
    local src = vim.fn.shellescape(vim.fn.expand("%"))
    -- Build into /tmp so problem folders stay clean (nothing to .gitignore).
    local bin = vim.fn.shellescape("/tmp/" .. vim.fn.expand("%:t:r"))
    vim.cmd("!" .. compiler .. " -O2 -Wall " .. src .. " -o " .. bin .. " && " .. bin)
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

-- Open the `origin` remote of the repo the current file/folder lives in on the
-- web. Normalizes SSH (git@host:owner/repo.git) and scp/ssh:// forms to https
-- and strips the trailing .git, then hands it to the browser helper.
vim.keymap.set('n', '<leader>go', function()
  local dir = vim.fn.expand('%:p:h')
  if dir == '' then dir = vim.fn.getcwd() end
  local out = vim.fn.systemlist({ 'git', '-C', dir, 'remote', 'get-url', 'origin' })
  if vim.v.shell_error ~= 0 or not out[1] or out[1] == '' then
    vim.notify('no origin remote found', vim.log.levels.WARN)
    return
  end
  local url = out[1]
  url = url:gsub('%.git$', '')
  url = url:gsub('^ssh://git@', 'https://')
  url = url:gsub('^git@([^:]+):', 'https://%1/')
  require('open_external').browser(url)
end, { desc = 'Git: open origin remote in browser' })

-- Open the URL / file under the cursor externally. Unlike the stock `gx`, local
-- files (.pptx, .docx, .xlsx, ...) go through xdg-open to their real desktop app
-- instead of being force-fed to $BROWSER (which just downloads/rejects them).
vim.keymap.set({ 'n', 'x' }, 'gx', function()
  require('open_external').open()
end, { desc = 'Open URL/file under cursor externally' })
vim.keymap.set({ 'n', 'x' }, '<leader>gx', function()
  require('open_external').open()
end, { desc = 'Open URL/file under cursor externally' })

vim.keymap.set('n', '<leader>w', function()
  vim.wo.wrap = not vim.wo.wrap
  print("wrap " .. (vim.wo.wrap and "on" or "off"))
end, { desc = 'Toggle line wrap' })

-- Tabs (tn/tc are taken by Python DAP debug mappings).
vim.keymap.set("n", "<leader>tt", "<cmd>tabnew<cr>",   { desc = "Tab: new" })
vim.keymap.set("n", "<leader>to", "<cmd>tabonly<cr>",  { desc = "Tab: close all others" })
