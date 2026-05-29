-- Git change indicators in the sign column, plus hunk stage/preview/blame.
return {
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      local gitsigns = require("gitsigns")

      gitsigns.setup({
        current_line_blame = false, -- toggle with <leader>gb
        on_attach = function(bufnr)
          local function map(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
          end

          -- Navigate hunks (changes)
          map("n", "]c", function() gitsigns.nav_hunk("next") end, "Next git hunk")
          map("n", "[c", function() gitsigns.nav_hunk("prev") end, "Prev git hunk")

          -- Act on hunks
          map("n", "<leader>hp", gitsigns.preview_hunk, "Git: preview hunk")
          map("n", "<leader>hs", gitsigns.stage_hunk, "Git: stage hunk")
          map("n", "<leader>hr", gitsigns.reset_hunk, "Git: reset hunk")
          map("v", "<leader>hs", function() gitsigns.stage_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "Git: stage selection")
          map("v", "<leader>hr", function() gitsigns.reset_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "Git: reset selection")

          -- Whole buffer
          map("n", "<leader>hS", gitsigns.stage_buffer, "Git: stage buffer")
          map("n", "<leader>hR", gitsigns.reset_buffer, "Git: reset buffer")

          -- Diffs & blame
          map("n", "<leader>hd", gitsigns.diffthis, "Git: diff this file")
          map("n", "<leader>gb", function() gitsigns.toggle_current_line_blame() end, "Git: toggle line blame")
          map("n", "<leader>hb", function() gitsigns.blame_line({ full = true }) end, "Git: blame line (full)")
        end,
      })
    end,
  },
}
