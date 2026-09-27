-- Use the system clipboard for all yank/delete/paste.
vim.opt.clipboard = "unnamedplus"

-- Enable the mouse in ALL modes, including terminal mode ('t'). Neovim's default
-- is "nvi" (normal/visual/insert only), which leaves the wheel dead inside a
-- terminal buffer -- e.g. the Claude split, which runs in terminal mode. With
-- "a" the wheel is forwarded to the terminal (or scrolls its scrollback), so you
-- can scroll the Claude window. Hover the window you want to scroll: the wheel
-- goes to the window under the pointer, not necessarily the focused one.
vim.opt.mouse = "a"

-- Treesitter-based folding; open files fully unfolded (folding opt-in via za/zM/zc).
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldtext = ""
vim.opt.foldlevelstart = 99

-- Create the parent directory on save if it doesn't exist.
vim.api.nvim_create_autocmd("BufWritePre", {
  callback = function()
    local dir = vim.fn.expand("<afile>:p:h")
    if vim.fn.isdirectory(dir) == 0 then
      vim.fn.mkdir(dir, "p")
    end
  end,
})
