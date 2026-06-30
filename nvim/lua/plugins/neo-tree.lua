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

      -- open the file under the cursor in the browser (images/pdf/html/svg).
      -- Key must be the resolved leader (" o"): neo-tree maps via
      -- nvim_buf_set_keymap, which does NOT expand "<leader>".
      m[(vim.g.mapleader or "\\") .. "o"] = function(state)
        local node = state.tree:get_node()
        if node and node.type == "file" then
          local file = node.path or node:get_id()
          -- follow $BROWSER (your default), then brave, then the system opener
          local browser = vim.env.BROWSER
          if (not browser or browser == "") and vim.fn.executable("brave-browser") == 1 then
            browser = "brave-browser"
          end
          if browser and browser ~= "" then
            vim.fn.jobstart({ browser, file }, { detach = true })
          elseif vim.fn.executable("xdg-open") == 1 then
            vim.fn.jobstart({ "xdg-open", file }, { detach = true })
          else
            vim.ui.open(file)
          end
          vim.notify("opened in browser: " .. vim.fn.fnamemodify(file, ":t"))
        else
          vim.notify("neo-tree: cursor is not on a file", vim.log.levels.INFO)
        end
      end

      return opts
    end,
  },
}

