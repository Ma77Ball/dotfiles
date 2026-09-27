-- Unified <leader>o for markdown: "open the thing under the cursor", whatever
-- it is. Tries, in order:
--   1) a markdown table   -> styled HTML table in Brave (md_table.lua)
--   2) a mermaid diagram  -> rendered PNG in the browser (diagram.nvim)
--   3) anything else       -> the URL / file path under the cursor (open_external)
--
-- Previously a table binding and a mermaid binding fought over <leader>o and the
-- table one always won, so <leader>o over a mermaid block reported "not on a
-- table". This dispatcher makes one key handle all of them.
local M = {}

local mermaid_opts = require("diagram_opts")
local renderer_modules = { mermaid = "diagram.renderers.mermaid" }

-- If the cursor sits inside a diagram code block, render it and return the
-- renderer result (which has .file_path, and .job_id if still rendering).
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

-- Open the (possibly still-rendering) diagram result in the browser.
local function open_diagram(res)
  local browser = require("open_external").browser
  if res.job_id then
    local timer = vim.loop.new_timer()
    if not timer then return end
    timer:start(0, 100, vim.schedule_wrap(function()
      if vim.fn.jobwait({ res.job_id }, 0)[1] ~= -1 then
        if timer:is_active() then timer:stop() end
        if not timer:is_closing() then timer:close() end
        browser(res.file_path)
      end
    end))
  else
    browser(res.file_path)
  end
end

function M.open()
  -- 1) table under cursor
  local ok_tbl, md_table = pcall(require, "md_table")
  if ok_tbl and md_table.on_table() then
    md_table.open()
    return
  end

  -- 2) mermaid diagram under cursor
  local res = render_result_at_cursor()
  if res then
    open_diagram(res)
    return
  end

  -- 3) fall back to opening a URL / file path under the cursor externally
  require("open_external").open()
end

return M
