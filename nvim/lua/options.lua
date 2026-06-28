-- Use the system clipboard for all yank/delete/paste.
vim.opt.clipboard = "unnamedplus"

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
