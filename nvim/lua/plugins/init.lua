return {
  {
    "jake-stewart/multicursor.nvim",
    branch = "1.0",
    event = "VeryLazy",
    config = function()
      local mc = require("multicursor-nvim")
      mc.setup()

      local set = vim.keymap.set

      -- Add a cursor on the line above/below
      set({ "n", "x" }, "<C-k>", function() mc.lineAddCursor(-1) end, { desc = "Add cursor up" })
      set({ "n", "x" }, "<C-j>", function() mc.lineAddCursor(1) end, { desc = "Add cursor down" })
      set({ "n", "x" }, "<C-Up>", function() mc.lineAddCursor(-1) end, { desc = "Add cursor up" })
      set({ "n", "x" }, "<C-Down>", function() mc.lineAddCursor(1) end, { desc = "Add cursor down" })

      -- Match the word/selection under the cursor
      set({ "n", "x" }, "<Leader>d", function() mc.matchAddCursor(1) end, { desc = "Add cursor at next match" })
      set({ "n", "x" }, "<Leader>A", function() mc.matchAddCursor(-1) end, { desc = "Add cursor at previous match" })
      set({ "n", "x" }, "<Leader>D", function() mc.matchSkipCursor(1) end, { desc = "Skip to next match" })
      set({ "n", "x" }, "<Leader>a", mc.matchAllAddCursors, { desc = "Add cursors to all matches" })

      -- Add a cursor on each line of the visual selection
      set("x", "<Leader>m", mc.addCursorOperator, { desc = "Add cursors over visual area" })

      -- Lock/unlock cursors
      set({ "n", "x" }, "<Leader>l", mc.toggleCursor, { desc = "Lock/unlock cursors" })

      -- Add or remove a cursor with control + left click
      set("n", "<C-LeftMouse>", mc.handleMouse)
      set("n", "<C-LeftDrag>", mc.handleMouseDrag)
      set("n", "<C-LeftRelease>", mc.handleMouseRelease)

      -- Only active while there are multiple cursors
      mc.addKeymapLayer(function(layerSet)
        layerSet({ "n", "x" }, "<Left>", mc.prevCursor)
        layerSet({ "n", "x" }, "<Right>", mc.nextCursor)
        layerSet({ "n", "x" }, "<Leader>x", mc.deleteCursor)
        layerSet("n", "<Esc>", function()
          if not mc.cursorsEnabled() then
            mc.enableCursors()
          else
            mc.clearCursors()
          end
        end)
      end)

      local hl = vim.api.nvim_set_hl
      hl(0, "MultiCursorCursor", { link = "Cursor" })
      hl(0, "MultiCursorVisual", { link = "Visual" })
      hl(0, "MultiCursorSign", { link = "SignColumn" })
      hl(0, "MultiCursorMatchPreview", { link = "Search" })
      hl(0, "MultiCursorDisabledCursor", { link = "Visual" })
      hl(0, "MultiCursorDisabledVisual", { link = "Visual" })
      hl(0, "MultiCursorDisabledSign", { link = "SignColumn" })
    end,
  },
}
