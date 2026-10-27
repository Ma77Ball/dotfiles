-- Shared mermaid render options, used by BOTH the inline diagram.nvim setup
-- (plugins/diagram.lua) and the <leader>o "open diagram in browser" path
-- (md_open.lua). They must match: diagram.nvim's renderer caches by source only,
-- so a render with different options would poison the inline view's cache.
return {
  theme = "dark", -- use "default" on a light colorscheme
  background = "transparent",
  -- mmdc renders at ~800px * scale wide. image.nvim only shrinks to fit the
  -- window (never upscales), so a small PNG shows sub-full-width on a wide/hi-DPI
  -- window. Scale up until the PNG is wider than the window and image.nvim's
  -- max_width cap binds (-> full width). Raise for bigger, lower if too big/slow.
  scale = 4,
}
