-- diagram.nvim: render mermaid/plantuml/d2 code blocks inline in markdown.
-- Renders each block to a PNG via a CLI (mmdc) and draws it via image.nvim.
-- Requires: image.nvim (plugins/image.lua), mmdc, a Chrome for puppeteer.
return {
  "3rd/diagram.nvim",
  dependencies = { "3rd/image.nvim" },
  ft = { "markdown" },
  config = function()
    -- point mmdc's puppeteer at the system Chrome (chromium download skipped)
    vim.env.PUPPETEER_EXECUTABLE_PATH = vim.env.PUPPETEER_EXECUTABLE_PATH
      or "/usr/bin/google-chrome"

    -- CursorHoldI fires after `updatetime` ms; lower it for snappier refresh
    if vim.o.updatetime > 700 then
      vim.opt.updatetime = 700
    end

    -- Open a file in the web browser. Follows your default browser via $BROWSER
    -- (falling back to brave, then the system opener) rather than hard-coding one.
    -- Inlined (not a required module) so it can't break on a stale vim.loader cache.
    local function open_in_browser(file)
      if not file or file == "" then
        vim.notify("browser: no file to open", vim.log.levels.WARN)
        return
      end
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
    end

    -- shared with the <leader>o resolver below so a forced render uses the same
    -- options as the inline one (the renderer caches by source only, so a render
    -- with different options would poison the cache for the inline view).
    local mermaid_opts = {
      theme = "dark", -- use "default" on a light colorscheme
      background = "transparent",
      scale = 2, -- crisper text; lower if diagrams feel too big
    }

    require("diagram").setup({
      integrations = {
        require("diagram.integrations.markdown"),
      },
      renderer_options = {
        mermaid = mermaid_opts,
      },
      -- re-render on these events; clear only on leaving the buffer
      events = {
        render_buffer = { "InsertEnter", "InsertLeave", "BufWinEnter", "TextChanged", "CursorHoldI" },
        clear_buffer = { "BufLeave" },
      },
    })

    -- <leader>o: open the diagram under the cursor in the browser (real zoom/pan,
    -- and free of the inline tall-image scroll glitch). The inline render has
    -- almost always cached the PNG already; if not, render then open when ready.
    local renderer_modules = { mermaid = "diagram.renderers.mermaid" }

    local function render_result_at_cursor()
      local ok_md, md = pcall(require, "diagram.integrations.markdown")
      if not ok_md then return nil end
      local bufnr = vim.api.nvim_get_current_buf()
      local row = vim.api.nvim_win_get_cursor(0)[1] - 1
      for _, d in ipairs(md.query_buffer_diagrams(bufnr)) do
        -- range covers the code-fence content; pad a line so the fences count too
        if row >= d.range.start_row - 1 and row <= d.range.end_row + 1 then
          local mod = renderer_modules[d.renderer_id]
          if mod then
            local ok_r, r = pcall(require, mod)
            if ok_r then return r.render(d.source, mermaid_opts) end
          end
        end
      end
      return nil
    end

    local function open_diagram_at_cursor()
      local res = render_result_at_cursor()
      if not res then
        vim.notify("no diagram under cursor", vim.log.levels.INFO)
        return
      end
      if res.job_id then
        local timer = vim.loop.new_timer()
        if not timer then return end
        timer:start(0, 100, vim.schedule_wrap(function()
          if vim.fn.jobwait({ res.job_id }, 0)[1] ~= -1 then
            if timer:is_active() then timer:stop() end
            if not timer:is_closing() then timer:close() end
            open_in_browser(res.file_path)
          end
        end))
      else
        open_in_browser(res.file_path)
      end
    end

    local function bind_leader_o(buf)
      -- respect an existing <leader>o (buffer-local or global)
      if vim.fn.maparg((vim.g.mapleader or "\\") .. "o", "n") ~= "" then return end
      vim.keymap.set("n", "<leader>o", open_diagram_at_cursor,
        { buffer = buf, desc = "Diagram: open block under cursor in browser" })
    end

    vim.api.nvim_create_autocmd("FileType", {
      pattern = "markdown",
      callback = function(ev) bind_leader_o(ev.buf) end,
    })
    -- the FileType that lazy-loaded this plugin already fired; bind open md bufs
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].filetype == "markdown" then
        bind_leader_o(b)
      end
    end
  end,
}
