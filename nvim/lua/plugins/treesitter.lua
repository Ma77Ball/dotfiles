return
{
	{
  'nvim-treesitter/nvim-treesitter',
  -- master is the stable, Nvim 0.11-compatible branch. The newer `main`
  -- branch requires Neovim 0.12+ (uses vim.list.unique etc.).
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
