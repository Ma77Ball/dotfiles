-- Use the system clipboard for all yank/delete/paste.
vim.opt.clipboard = "unnamedplus"

-- Indentation: 2-space, spaces only. Keeps typing/Enter aligned with what
-- clang-format produces on save (LLVM base, IndentWidth 2), so a new line lands
-- at the right column instead of an 8-wide tab stop. Filetypes that require tabs
-- (Makefiles, Go) get them back from their own ftplugin.
vim.opt.expandtab = true      -- <Tab> inserts spaces
vim.opt.shiftwidth = 2        -- size of an indent (>>, autoindent, o/O)
vim.opt.tabstop = 2           -- a literal tab renders as 2 columns
vim.opt.softtabstop = 2       -- <Tab>/<BS> move by 2 in insert mode
vim.opt.autoindent = true     -- new line keeps the current indent
vim.opt.smartindent = true    -- add an indent after {, etc.

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
