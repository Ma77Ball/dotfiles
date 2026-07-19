-- Shared <leader>cJ expander for json/jsonc/jsonl buffers.
-- Pretty-prints JSON into a READ-ONLY scratch split so a minified/long line can
-- be read without ever rewriting the file on disk. Used by:
--   ftplugin/jsonl.lua  -> scope "line"   (one object per line; expand the one under the cursor)
--   ftplugin/json.lua   -> scope "buffer" (whole file is a single document)
--   ftplugin/jsonc.lua  -> scope "buffer"
local M = {}

-- scope: "line" expands the record under the cursor; "buffer" expands the whole file.
function M.expand(scope)
  local input
  local label
  local src = vim.fn.expand("%:t")
  if scope == "line" then
    input = vim.api.nvim_get_current_line()
    label = string.format("[json %s:%d]", src, vim.api.nvim_win_get_cursor(0)[1])
  else
    input = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
    label = string.format("[json %s]", src)
  end

  if vim.trim(input) == "" then
    vim.notify("json: nothing to expand", vim.log.levels.WARN)
    return
  end

  local out = vim.fn.systemlist({ "jq", "." }, input)
  if vim.v.shell_error ~= 0 then
    vim.notify("json: jq failed -- " .. table.concat(out, " "), vim.log.levels.ERROR)
    return
  end

  -- scratch buffer: nofile/wipe so it can never be saved back over the source
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, out)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "json"
  vim.bo[buf].modifiable = false
  vim.api.nvim_buf_set_name(buf, label)

  -- Float, NOT a split: overlays the layout so neo-tree / the claude terminal /
  -- the middle window keep their widths. Nothing reflows on open or close.
  local maxw = 0
  for _, l in ipairs(out) do
    maxw = math.max(maxw, vim.fn.strdisplaywidth(l))
  end
  local width = math.max(40, math.min(maxw + 2, math.floor(vim.o.columns * 0.9)))
  local height = math.max(1, math.min(#out, math.floor(vim.o.lines * 0.85)))
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " " .. label .. " ",
    title_pos = "center",
  })
  vim.wo[win].wrap = false
  vim.wo[win].cursorline = true
  for _, key in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", key, "<cmd>close<cr>", { buffer = buf, nowait = true, silent = true })
  end
end

-- Register <leader>cf in the current (buffer-local) ftplugin context.
function M.map(scope)
  local desc = scope == "line"
    and "JSON: expand record under cursor (read-only)"
    or "JSON: expand buffer (read-only)"
  vim.keymap.set("n", "<leader>cf", function()
    M.expand(scope)
  end, { buffer = true, desc = desc })
end

return M
