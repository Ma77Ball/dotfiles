return {
  'MeanderingProgrammer/render-markdown.nvim',
  dependencies = {
    'nvim-treesitter/nvim-treesitter',
    'nvim-tree/nvim-web-devicons', -- optional icons; remove if you don't use devicons
  },
  ft = { 'markdown' },
  opts = {},
  config = function(_, opts)
    require('render-markdown').setup(opts)
    -- Toggle rendering on/off
    vim.keymap.set('n', '<leader>tm', '<cmd>RenderMarkdown toggle<cr>',
      { desc = 'Toggle markdown rendering' })
  end,
}
