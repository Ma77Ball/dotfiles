-- nvim-treesitter: syntax-aware highlighting, indentation, and folding.
return
{
	{
  'nvim-treesitter/nvim-treesitter',
  -- master: the Nvim 0.11-compatible branch.
  branch = 'master',
  lazy = false,
  build = ':TSUpdate',
  config = function()
    require('nvim-treesitter.configs').setup({
      ensure_installed = {
        'java', 'lua', 'python', 'scala',
        'typescript', 'tsx', 'javascript',
      },
      auto_install = true,
      highlight = { enable = true },
      indent = { enable = true },
    })
  end,
}
}
