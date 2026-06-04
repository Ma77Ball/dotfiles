-- Use the system clipboard for all yank/delete/paste, so `y` copies to it.
vim.opt.clipboard = "unnamedplus"

-- Treesitter-based folding (works for TypeScript/TSX and any language with a
-- parser installed). foldexpr drives the folds; foldlevelstart = 99 opens
-- files fully unfolded so folding is opt-in via za/zM/zc.
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldtext = ""
vim.opt.foldlevelstart = 99

vim.api.nvim_create_autocmd("BufWritePre", {
  callback = function()
    local dir = vim.fn.expand("<afile>:p:h")
    if vim.fn.isdirectory(dir) == 0 then
      vim.fn.mkdir(dir, "p")
    end
  end,
})
