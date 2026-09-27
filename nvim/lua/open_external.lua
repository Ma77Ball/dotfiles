-- Open the URL or file path under the cursor in the right external app.
--   * URLs (http/https/www/...) go to the web browser
--   * local files (.pptx/.docx/.xlsx, images, pdf, ...) go to the desktop
--     default handler via `xdg-open`
--
-- The key fix vs. plain `gx`: local files are opened with `xdg-open`, NOT with
-- $BROWSER. With BROWSER=brave-browser set, the stock gx feeds everything to
-- Brave, so a local .pptx just gets downloaded/rejected instead of opening in
-- LibreOffice. Routing local files through xdg-open uses the correct app.
local M = {}

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "open" })
end

local function is_url(t)
  return t:match("^%a[%w+.-]*://") ~= nil or t:match("^www%.") ~= nil
end

-- Find the best "openable" target near the cursor:
--   1) the current visual selection (when called from visual mode),
--   2) a markdown link target [text](dest) the cursor is inside,
--   3) a URL sitting inside the current WORD,
--   4) <cfile>, the file/URL Vim itself recognizes under the cursor.
-- Exposed as M.target for testing/inspection.
local function target_at_cursor()
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" or mode == "\22" then
    local ok, region = pcall(vim.fn.getregion, vim.fn.getpos("v"), vim.fn.getpos("."), { type = mode })
    if ok and region and #region > 0 then
      local t = vim.trim(table.concat(region, ""))
      if t ~= "" then return t end
    end
  end

  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1 -- 1-indexed byte column
  -- markdown link: return the dest of the [text](dest) span under the cursor
  local init = 1
  while true do
    local s, e, dest = line:find("%[.-%]%((.-)%)", init)
    if not s then break end
    if col >= s and col <= e then return vim.trim(dest) end
    init = e + 1
  end

  -- quoted / backticked span under the cursor (handles paths with spaces, which
  -- <cfile>/<cWORD> would truncate). Try each delimiter; take the span the
  -- cursor sits inside.
  for _, q in ipairs({ '"', "'", "`" }) do
    local from = 1
    while true do
      local s, e, inner = line:find(q .. "([^" .. q .. "]+)" .. q, from)
      if not s then break end
      if col >= s and col <= e then return vim.trim(inner) end
      from = e + 1
    end
  end

  local cword = vim.fn.expand("<cWORD>")
  local url = cword:match("%a[%w+.-]*://[%w%-._~:/?#%[%]@!$&'()*+,;=%%]+")
    or cword:match("www%.[%w%-._~:/?#%[%]@!$&'()*+,;=%%]+")
  if url then
    -- trim trailing prose punctuation the WORD grabbed (e.g. "url),") but keep a
    -- ')' that closes a '(' inside the URL itself.
    url = url:gsub("[.,;:!?]+$", "")
    if not url:find("%(") then url = url:gsub("%)+$", "") end
    return url
  end

  local cfile = vim.fn.expand("<cfile>")
  -- ignore junk (e.g. a lone table pipe): require at least one word character
  if cfile ~= "" and cfile:match("%w") then return cfile end
  return nil
end

-- Launch a URL (or any target that should live in the browser, e.g. a rendered
-- PNG) in $BROWSER, then brave, then xdg-open, then vim.ui.open.
function M.browser(target)
  if not target or target == "" then
    notify("nothing to open in the browser", vim.log.levels.WARN)
    return
  end
  if target:match("^www%.") then target = "https://" .. target end
  local browser = vim.env.BROWSER
  if (not browser or browser == "") and vim.fn.executable("brave-browser") == 1 then
    browser = "brave-browser"
  end
  if browser and browser ~= "" and vim.fn.executable(browser) == 1 then
    vim.fn.jobstart({ browser, target }, { detach = true })
  elseif vim.fn.executable("xdg-open") == 1 then
    vim.fn.jobstart({ "xdg-open", target }, { detach = true })
  else
    vim.ui.open(target)
  end
  notify("opened in browser: " .. vim.fn.fnamemodify(target, ":t"))
end

local function exists(p)
  return vim.fn.filereadable(p) == 1 or vim.fn.isdirectory(p) == 1
end

-- Roots to resolve a relative target against: the buffer's directory, then cwd.
local function roots()
  local list = {}
  local bufdir = vim.fn.expand("%:p:h")
  if bufdir ~= "" and bufdir ~= "." then list[#list + 1] = bufdir end
  local cwd = vim.fn.getcwd()
  if cwd ~= list[1] then list[#list + 1] = cwd end
  return list
end

-- Common places a generated/mentioned file tends to live, tried before a full
-- recursive search (the pptx/md skills write to reference/, artifacts, etc.).
local SUBDIRS = { "", "reference", "artifacts", "docs", "slides", "out" }

-- Locate a (possibly relative / bare-basename) target. Returns
-- (abspath|nil, n_matches). Tiers: exact under known subdirs, then a
-- depth-limited recursive search for the basename under each root.
local function locate(path)
  path = vim.fn.expand(path) -- expand ~ and $ENV
  if path:match("^/") then
    return (exists(path) and path or nil), 1
  end
  for _, r in ipairs(roots()) do
    for _, sub in ipairs(SUBDIRS) do
      local c = (sub == "") and (r .. "/" .. path) or (r .. "/" .. sub .. "/" .. path)
      if exists(c) then return vim.fn.fnamemodify(c, ":p"), 1 end
    end
  end
  -- recursive fallback: match the basename up to 4 levels deep under each root
  local base = vim.fn.fnamemodify(path, ":t")
  for _, r in ipairs(roots()) do
    for _, depth in ipairs({ "*/", "*/*/", "*/*/*/", "*/*/*/*/" }) do
      local m = vim.fn.globpath(r, depth .. base, false, true)
      if #m > 0 then return vim.fn.fnamemodify(m[1], ":p"), #m end
    end
  end
  return nil, 0
end

-- Open a local file with the desktop default handler (xdg-open). This is what
-- makes .pptx/.docx/.xlsx open in their real app instead of the browser.
function M.file(path)
  local full, n = locate(path)
  if not full then
    local where = {}
    for _, r in ipairs(roots()) do where[#where + 1] = vim.fn.fnamemodify(r, ":~") end
    notify("no such file: '" .. path .. "'  (searched " .. table.concat(where, ", ")
      .. " incl. reference/, artifacts/, and recursively)", vim.log.levels.WARN)
    return
  end
  if vim.fn.executable("xdg-open") == 1 then
    vim.fn.jobstart({ "xdg-open", full }, { detach = true })
  else
    vim.ui.open(full)
  end
  local extra = (n and n > 1) and (" (" .. n .. " matches)") or ""
  notify("opened: " .. vim.fn.fnamemodify(full, ":~") .. extra)
end

-- Exposed for inspection/testing: what would gx open, and how.
function M.target()
  return target_at_cursor()
end

-- Entry point for gx / <leader>gx: grab the target under the cursor and route it.
function M.open()
  local t = target_at_cursor()
  if not t or t == "" then
    notify("nothing to open under the cursor", vim.log.levels.WARN)
    return
  end
  if is_url(t) then M.browser(t) else M.file(t) end
end

return M
