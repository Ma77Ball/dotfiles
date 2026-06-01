-- Highlights merge conflict markers and gives one-key Ours/Theirs/Both/None resolution.
return {
  {
    "akinsho/git-conflict.nvim",
    version = "*",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("git-conflict").setup({
        default_mappings = false, -- we define our own below
        disable_diagnostics = false,
        highlights = {
          incoming = "DiffAdd",
          current = "DiffText",
        },
      })

      -- Resolve / navigate conflicts (active only in buffers with conflicts)
      local function map(lhs, rhs, desc)
        vim.keymap.set("n", lhs, rhs, { desc = desc })
      end

      -- <leader>cb is taken by Claude (add file), so "both" uses capital cB
      map("<leader>co", "<Plug>(git-conflict-ours)", "Conflict: choose ours")
      map("<leader>ct", "<Plug>(git-conflict-theirs)", "Conflict: choose theirs")
      map("<leader>cB", "<Plug>(git-conflict-both)", "Conflict: choose both")
      map("<leader>cn", "<Plug>(git-conflict-none)", "Conflict: choose none")
      map("]x", "<Plug>(git-conflict-next-conflict)", "Conflict: next")
      map("[x", "<Plug>(git-conflict-prev-conflict)", "Conflict: prev")

      -- Step through merge-conflicted files one by one.
      -- Builds a quickfix list of every unmerged file (positioned at its first
      -- conflict marker) and drops you straight INTO the first one, in the real
      -- editable file buffer -- so the resolve keys above work immediately.
      local function conflict_step()
        local root = vim.trim(vim.fn.system({ "git", "rev-parse", "--show-toplevel" }))
        if vim.v.shell_error ~= 0 then
          vim.notify("Not inside a git repository", vim.log.levels.ERROR)
          return
        end
        local files = vim.fn.systemlist({ "git", "-C", root, "diff", "--name-only", "--diff-filter=U" })
        if vim.v.shell_error ~= 0 or #files == 0 then
          vim.notify("No merge conflicts ", vim.log.levels.INFO)
          return
        end
        local items = {}
        for _, rel in ipairs(files) do
          local path = root .. "/" .. rel
          local lnum = 1
          local ok, lines = pcall(vim.fn.readfile, path)
          if ok then
            for i, line in ipairs(lines) do
              if line:match("^<<<<<<<") then
                lnum = i
                break
              end
            end
          end
          table.insert(items, { filename = path, lnum = lnum, col = 1, text = "git conflict" })
        end
        vim.fn.setqflist({}, "r", { title = "Merge conflicts", items = items })
        vim.cmd("cfirst") -- jump into the first conflicted file (a modifiable buffer)
        vim.notify(
          ("%d conflicted file(s) -- ]q / [q to move between files, ]x / [x between conflicts"):format(#items),
          vim.log.levels.INFO
        )
      end

      map("<leader>cq", conflict_step, "Conflict: step through conflicted files")
      map("]q", "<cmd>cnext<cr>", "Conflict: next file")
      map("[q", "<cmd>cprev<cr>", "Conflict: prev file")

      -- Stage the current (resolved) file with `git add` and jump to the next
      -- conflicted file. Refuses to stage if conflict markers are still present.
      local function conflict_stage()
        local file = vim.fn.expand("%:p")
        if file == "" then
          vim.notify("No file in current buffer", vim.log.levels.WARN)
          return
        end
        if vim.bo.modified then vim.cmd("write") end
        local ok, lines = pcall(vim.fn.readfile, file)
        if ok then
          for _, line in ipairs(lines) do
            if line:match("^<<<<<<<") or line:match("^=======$") or line:match("^>>>>>>>") then
              vim.notify("Conflict markers still present -- resolve them before staging", vim.log.levels.ERROR)
              return
            end
          end
        end
        vim.fn.system({ "git", "add", "--", file })
        if vim.v.shell_error ~= 0 then
          vim.notify("git add failed", vim.log.levels.ERROR)
          return
        end
        vim.notify("Staged " .. vim.fn.fnamemodify(file, ":t"), vim.log.levels.INFO)
        conflict_step() -- rebuild list and jump to the next conflicted file
      end

      map("<leader>cs", conflict_stage, "Conflict: stage current file & go to next")
    end,
  },
}
