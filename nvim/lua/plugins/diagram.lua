-- Inline rendering of mermaid (and plantuml/d2) code blocks in markdown.
-- diagram.nvim renders each fenced diagram to a PNG via a CLI (mmdc for
-- mermaid) and draws it inline through image.nvim (ghostty / kitty protocol).
--
-- Requirements (already satisfied on this machine):
--   * image.nvim          -> see plugins/image.lua (kitty backend, magick CLI)
--   * mmdc                -> ~/.local/bin/mmdc (npm @mermaid-js/mermaid-cli)
--   * a Chrome/Chromium   -> /usr/bin/google-chrome (puppeteer needs a browser)
--
-- Behaviour: the diagram is ALWAYS shown, INCLUDING while you edit the source.
-- It is (re)rendered when you enter insert mode and when you pause typing
-- (CursorHoldI), so it stays visible the whole time you work on the diagram
-- text. Renders are cheap: diagram.nvim caches each renderer's PNG by a hash of
-- the source, so re-render events with unchanged text are instant (no CLI spawn)
-- and only an actual text change re-runs the renderer. Applies to every diagram
-- language diagram.nvim supports (mermaid, plantuml, d2), not just mermaid.
return {
  "3rd/diagram.nvim",
  dependencies = { "3rd/image.nvim" },
  ft = { "markdown" },
  config = function()
    -- mmdc -> puppeteer needs a browser. We skipped puppeteer's own chromium
    -- download at install time, so point it at the system Chrome. Setting it on
    -- vim.env means every mmdc child process nvim spawns inherits it.
    vim.env.PUPPETEER_EXECUTABLE_PATH = vim.env.PUPPETEER_EXECUTABLE_PATH
      or "/usr/bin/google-chrome"

    -- CursorHoldI fires after `updatetime` ms of no typing. Keep it reasonably
    -- snappy so the diagram refreshes soon after you pause, but only lower it
    -- (never raise someone's already-low setting).
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
      -- Always show, including while editing:
      --   InsertEnter  -> re-show (from cache) the moment you start editing
      --   CursorHoldI  -> refresh on a typing pause inside the block (live-ish)
      --   InsertLeave / TextChanged -> refresh after edits in normal mode
      --   BufWinEnter  -> render on open
      -- Only cleared when leaving the buffer (so images don't bleed onto another
      -- file); never cleared on InsertEnter, so it does not vanish while typing.
      events = {
        render_buffer = { "InsertEnter", "InsertLeave", "BufWinEnter", "TextChanged", "CursorHoldI" },
        clear_buffer = { "BufLeave" },
      },
    })
  end,
}
