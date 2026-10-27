-- nvim-ts-autotag: treesitter-aware HTML/JSX tag editing.
-- Typing `>` to close an opening tag inserts the matching `</tag>`; renaming
-- one half of a pair renames the other. Works in html/xml and in jsx/tsx.
return {
  {
    "windwp/nvim-ts-autotag",
    ft = { "html", "xml", "javascriptreact", "typescriptreact", "javascript", "typescript" },
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    config = function()
      require("nvim-ts-autotag").setup()
    end,
  },
}
