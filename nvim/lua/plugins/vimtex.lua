-- vimtex: LaTeX compilation, PDF viewing, navigation, and motions.
-- Highlighting is left to the treesitter `latex` parser (vimtex_syntax_enabled = 0)
-- to avoid double-highlighting. The engine is chosen by the project's .latexmkrc
-- (this repo uses lualatex), so we do NOT hardcode an engine here.
return {
  {
    "lervag/vimtex",
    ft = { "tex", "latex" },
    init = function()
      -- This vimtex release demands neovim 0.12.4; we're on 0.11.6. The check is
      -- conservative (no 0.12-only APIs are used at init), so skip it. If a future
      -- `lazy update` pulls code that truly needs 0.12, pin: version = "v2.18".
      vim.g.vimtex_version_check = 0

      -- Compile with latexmk; it reads .latexmkrc for the engine (pdf_mode).
      vim.g.vimtex_compiler_method = "latexmk"

      -- View the PDF in Brave (uses Brave's built-in PDF viewer).
      -- Note: no SyncTeX with a browser, and Brave won't auto-refresh on
      -- recompile -- reload the tab (Ctrl-R) to see changes.
      vim.g.vimtex_view_method = "general"
      vim.g.vimtex_view_general_viewer = "brave-browser"
      vim.g.vimtex_view_general_options = "@pdf"

      -- Defer syntax highlighting to nvim-treesitter's latex parser.
      vim.g.vimtex_syntax_enabled = 0

      -- Quieter: don't auto-open the quickfix on warnings, only on real errors.
      vim.g.vimtex_quickfix_open_on_warning = 0
    end,
  },
}
-- Default buffer-local mappings (localleader = "\\"):
--   \ll  compile continuously (recompiles on save)   \lk  stop compilation
--   \lv  view the PDF                                 \lc  clean aux files
--   \le  open the quickfix error list                \lt  toggle table of contents
