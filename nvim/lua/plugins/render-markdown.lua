-- render-markdown.nvim: in-buffer rendering of markdown (headings, lists, code).
return {
  'MeanderingProgrammer/render-markdown.nvim',
  dependencies = {
    'nvim-treesitter/nvim-treesitter',
    'nvim-tree/nvim-web-devicons', -- icons
  },
  ft = { 'markdown' },
  opts = {},
}
