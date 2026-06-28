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

    require("diagram").setup({
      integrations = {
        require("diagram.integrations.markdown"),
      },
      renderer_options = {
        mermaid = {
          theme = "dark", -- use "default" on a light colorscheme
          background = "transparent",
          scale = 2, -- crisper text; lower if diagrams feel too big
        },
      },
      -- re-render on these events; clear only on leaving the buffer
      events = {
        render_buffer = { "InsertEnter", "InsertLeave", "BufWinEnter", "TextChanged", "CursorHoldI" },
        clear_buffer = { "BufLeave" },
      },
    })
  end,
}
