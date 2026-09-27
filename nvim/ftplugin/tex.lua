-- LaTeX shortcuts for tex buffers. Single function keys = no leader, no Shift,
-- no key-sequence timing. These only apply inside .tex buffers.
-- They call vimtex's <Plug> maps, so they need vimtex loaded (restart nvim once
-- after install). If a key does nothing, run :VimtexCompile to confirm vimtex is up.
local map = function(lhs, plug, desc)
  vim.keymap.set("n", lhs, plug, { buffer = true, remap = true, desc = desc })
end

-- Primary: just press the key.
map("<F2>", "<plug>(vimtex-compile)", "LaTeX: compile (continuous, rebuilds on save)")
map("<F3>", "<plug>(vimtex-view)",    "LaTeX: view PDF")
map("<F4>", "<plug>(vimtex-clean)",   "LaTeX: clean aux files")

-- Secondary (space-based), for when you prefer leader keys:
map("<leader>Ll", "<plug>(vimtex-compile)",    "LaTeX: compile (continuous)")
map("<leader>Ls", "<plug>(vimtex-compile-ss)", "LaTeX: compile once")
map("<leader>Lv", "<plug>(vimtex-view)",       "LaTeX: view PDF")
map("<leader>Le", "<plug>(vimtex-errors)",     "LaTeX: error list")
map("<leader>Lt", "<plug>(vimtex-toc-open)",   "LaTeX: table of contents")
map("<leader>Lc", "<plug>(vimtex-clean)",      "LaTeX: clean aux files")
map("<leader>Lk", "<plug>(vimtex-stop)",       "LaTeX: stop compilation")
