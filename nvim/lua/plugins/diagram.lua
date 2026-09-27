-- diagram.nvim: render mermaid/plantuml/d2 code blocks inline in markdown.
-- Renders each block to a PNG via a CLI (mmdc) and draws it via image.nvim.
-- Requires: image.nvim (plugins/image.lua), mmdc, a Chrome for puppeteer.
--
-- The <leader>o "open diagram under cursor in browser" mapping lives in
-- lua/md_open.lua (a unified dispatcher shared with the table renderer). The
-- mermaid render options are shared via lua/diagram_opts.lua so the forced
-- render and the inline render hit the same renderer cache.
return {
  "3rd/diagram.nvim",
  dependencies = { "3rd/image.nvim" },
  ft = { "markdown" },
  config = function()
    -- point mmdc's puppeteer at Brave (chromium download skipped). Puppeteer's
    -- bundled Chrome is often a version mmdc can't find ("Could not find
    -- Chrome ..."), so drive the installed Brave binary instead.
    vim.env.PUPPETEER_EXECUTABLE_PATH = vim.env.PUPPETEER_EXECUTABLE_PATH
      or "/opt/brave.com/brave/brave"

    -- CursorHoldI fires after `updatetime` ms; lower it for snappier refresh
    if vim.o.updatetime > 700 then
      vim.opt.updatetime = 700
    end

    require("diagram").setup({
      integrations = {
        require("diagram.integrations.markdown"),
      },
      renderer_options = {
        mermaid = require("diagram_opts"),
      },
      -- re-render on these events; clear only on leaving the buffer
      events = {
        render_buffer = { "InsertEnter", "InsertLeave", "BufWinEnter", "TextChanged", "CursorHoldI" },
        clear_buffer = { "BufLeave" },
      },
    })
  end,
}
