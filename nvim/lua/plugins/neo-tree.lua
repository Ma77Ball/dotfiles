-- neo-tree: file explorer sidebar (filesystem and git-status sources).
return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons",
    },

    lazy = false,

    keys = {
      { "<leader>pv", "<cmd>Neotree filesystem toggle reveal<CR>", desc = "Neo-tree filesystem" },
      { "<leader>pg", "<cmd>Neotree git_status toggle<CR>", desc = "Neo-tree git status" },
    },

    opts = function(_, opts)
      opts = opts or {}
      opts.filesystem = opts.filesystem or {}

      -- hide large/noisy dirs from the tree
      opts.filesystem.filtered_items = vim.tbl_deep_extend("force",
        opts.filesystem.filtered_items or {},
        {
          hide_by_name = {
            "node_modules",
            ".git",
            "dist",
            "target",
          },
        }
      )

      opts.filesystem.window = opts.filesystem.window or {}
      opts.filesystem.window.mappings = opts.filesystem.window.mappings or {}
      local m = opts.filesystem.window.mappings

      -- recursive fuzzy search
      m["/"] = "fuzzy_finder"

      -- persistent filter on visible nodes
      m["f"] = "filter_on_submit"
      m["F"] = "clear_filter"

      -- expand all folders / expand folder under cursor (z = collapse, default)
      m["Z"] = "expand_all_nodes"
      m["E"] = "expand_all_subnodes"

      -- open but keep neo-tree focused
      m["<CR>"] = { "open", config = { keep_focus = true } }
      m["o"]    = { "open", config = { keep_focus = true } }
      m["s"]    = { "open_split",  config = { keep_focus = true } }
      m["v"]    = { "open_vsplit", config = { keep_focus = true } }

      return opts
    end,
  },
}

