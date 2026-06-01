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
      -- Force filesystem source so you’re not accidentally in git_status/buffers
      { "<leader>pv", "<cmd>Neotree filesystem toggle reveal<CR>", desc = "Neo-tree filesystem" },
      -- Git changes only: lists just the files with git edits (staged/unstaged/untracked)
      { "<leader>pg", "<cmd>Neotree git_status toggle<CR>", desc = "Neo-tree git status" },
    },

    opts = function(_, opts)
      opts = opts or {}
      opts.filesystem = opts.filesystem or {}

      -- Optional but VERY helpful for search performance + to avoid huge dirs
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

      -- ✅ Project-wide search (recursive)
      m["/"] = "fuzzy_finder"

      -- ✅ Visible-nodes-only filter (persistent)
      m["f"] = "filter_on_submit"
      m["F"] = "clear_filter"

      -- ✅ Expand / collapse the whole tree
      m["Z"] = "expand_all_nodes"   -- expand every folder recursively
      -- (little `z` = close_all_nodes is already a neo-tree default)
      -- Expand just the folder under the cursor and its children:
      m["E"] = "expand_all_subnodes"

      -- ✅ Open but keep Neo-tree focused
      m["<CR>"] = { "open", config = { keep_focus = true } }
      m["o"]    = { "open", config = { keep_focus = true } }
      m["s"]    = { "open_split",  config = { keep_focus = true } }
      m["v"]    = { "open_vsplit", config = { keep_focus = true } }

      return opts
    end,
  },
}

