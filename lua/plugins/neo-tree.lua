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
      { "<leader>pv", "<cmd>Neotree toggle<CR>", desc = "Neo-tree toggle" },
    },

    opts = function(_, opts)
      opts = opts or {}
      opts.filesystem = opts.filesystem or {}
      opts.filesystem.window = opts.filesystem.window or {}
      opts.filesystem.window.mappings = opts.filesystem.window.mappings or {}

      local m = opts.filesystem.window.mappings

      -- ✅ Make `/` a persistent filter (type scala + Enter; filter stays)
      m["/"] = "filter_on_submit"
      m["F"] = "clear_filter"

      -- ✅ Open files but KEEP Neo-tree focused
      m["<CR>"] = { "open", config = { keep_focus = true } }
      m["o"]    = { "open", config = { keep_focus = true } }
      m["s"]    = { "open_split",  config = { keep_focus = true } }
      m["v"]    = { "open_vsplit", config = { keep_focus = true } }

      return opts
    end,
  },
}

