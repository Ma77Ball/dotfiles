-- Side-by-side git diffs with a file panel, plus file/branch history.
-- Lazy-loaded on its commands and keymaps so startup stays fast.
return {
  {
    "sindrets/diffview.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = {
      "DiffviewOpen",
      "DiffviewClose",
      "DiffviewToggleFiles",
      "DiffviewFocusFiles",
      "DiffviewFileHistory",
    },
    -- :DiffUp [ref] -> diff against upstream main (or a given ref).
    -- Defined in init so the command exists at startup before the plugin loads.
    init = function()
      vim.api.nvim_create_user_command("DiffUp", function(o)
        local base = o.args ~= "" and o.args or nil
        if not base then
          for _, ref in ipairs({ "upstream/main", "origin/main", "main" }) do
            local out = vim.fn.systemlist("git rev-parse --verify --quiet " .. ref)
            if vim.v.shell_error == 0 and out[1] and out[1] ~= "" then
              base = ref
              break
            end
          end
        end
        if base then
          vim.cmd("DiffviewOpen " .. base)
        else
          vim.notify("Diffview: no upstream/main found to diff against", vim.log.levels.WARN)
        end
      end, {
        nargs = "?",
        complete = function(arglead)
          local refs = vim.fn.systemlist(
            "git for-each-ref --format='%(refname:short)' refs/heads refs/remotes refs/tags"
          )
          return vim.tbl_filter(function(r)
            return r:find(arglead, 1, true) == 1
          end, refs)
        end,
        desc = "Diffview against upstream main (or a given ref)",
      })
    end,
    keys = {
      -- working tree vs HEAD, or with a count N, vs HEAD~N
      {
        "<leader>gd",
        function()
          local n = vim.v.count
          vim.cmd(n > 0 and ("DiffviewOpen HEAD~" .. n) or "DiffviewOpen")
        end,
        desc = "Diffview: working tree (or N commits back with a count)",
      },
      -- diff against the previous commit
      { "<leader>gD", "<cmd>DiffviewOpen HEAD~1<cr>", desc = "Diffview: open vs HEAD~1" },
      -- diff against upstream main (branch's total changes)
      { "<leader>gu", "<cmd>DiffUp<cr>", desc = "Diffview: vs upstream main" },
      { "<leader>gc", "<cmd>DiffviewClose<cr>", desc = "Diffview: close" },
      -- file history, then whole repo/branch history
      { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "Diffview: file history" },
      { "<leader>gH", "<cmd>DiffviewFileHistory<cr>", desc = "Diffview: repo history" },
    },
    opts = {
      enhanced_diff_hl = true, -- richer in-diff highlighting
      view = {
        -- two-column side-by-side; three-way for merges
        default = { layout = "diff2_horizontal" },
        merge_tool = { layout = "diff3_horizontal" },
      },
    },
  },
}
