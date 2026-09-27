-- Shared mermaid render options, used by BOTH the inline diagram.nvim setup
-- (plugins/diagram.lua) and the <leader>o "open diagram in browser" path
-- (md_open.lua). They must match: diagram.nvim's renderer caches by source only,
-- so a render with different options would poison the inline view's cache.
return {
  theme = "dark", -- use "default" on a light colorscheme
  background = "transparent",
  scale = 2, -- crisper text; lower if diagrams feel too big
}
