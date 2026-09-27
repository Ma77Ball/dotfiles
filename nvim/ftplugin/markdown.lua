-- Markdown buffers: <leader>o "opens the thing under the cursor" -- a table as a
-- styled HTML page, a mermaid diagram as a rendered image, or otherwise the URL /
-- file path under the cursor. Dispatcher in lua/md_open.lua.
vim.keymap.set("n", "<leader>o", function()
  require("md_open").open()
end, { buffer = true, desc = "Open table/diagram/link under cursor" })
