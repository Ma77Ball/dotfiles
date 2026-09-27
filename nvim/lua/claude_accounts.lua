-- Multi-account switcher/manager for claudecode.nvim.
--
-- Each account is just a separate CLAUDE_CONFIG_DIR (its own credentials +
-- settings). claudecode.nvim re-reads its `env` table on every terminal open and
-- wires the IDE integration through an injected CLAUDE_CODE_SSE_PORT (not the
-- config dir), so overriding CLAUDE_CONFIG_DIR per-launch switches the account
-- while keeping diffs / send-selection working.
--
-- A Claude process's auth is fixed at launch, so there is no live token swap:
-- switching closes the current session and relaunches under the chosen account.
--
-- <leader>ca opens a manager (vim.ui.select):
--   * pick an account          -> relaunch Claude under it
--   * "+ Add account..."       -> register a new CLAUDE_CONFIG_DIR (created if
--                                 missing) and log into it
--   * "~ Rename account..."    -> change an account's name and/or its dir
--   * "x Delete account..."    -> drop it from the switcher, optionally rm -rf
--                                 its dir from disk (guarded, opt-in)
--
-- The account list lives in SAVE_FILE and is the single source of truth. On the
-- very first run it is seeded from BUILTIN_SEED below (the entries whose dir
-- exists), after which it is fully user-managed and edits persist across
-- restarts.
local M = {}

-- Shared launch settings -- keep in sync with plugins/claude.lua's setup().
local TERM_CMD = "claude --permission-mode auto --model claude-opus-4-8"
local TERM_OPTS = { provider = "native", split_width_percentage = 0.30 }

-- Where the account list is persisted (a JSON array of { name, dir }).
local SAVE_FILE = vim.fn.stdpath("data") .. "/claude_accounts.json"

-- First-run seed only. Entries whose dir does not exist are skipped, so this
-- stays portable across machines that only have the personal account.
local BUILTIN_SEED = {
  { name = "personal", dir = vim.fn.expand("~/.claude") },
  { name = "work", dir = vim.fn.expand("~/.claude-work") },
}

-- ---------------------------------------------------------------------------
-- Persistence
-- ---------------------------------------------------------------------------

local function persist(list)
  local f = io.open(SAVE_FILE, "w")
  if not f then
    vim.notify("Could not write " .. SAVE_FILE, vim.log.levels.ERROR)
    return false
  end
  f:write(vim.json.encode(list))
  f:close()
  return true
end

-- The authoritative account list. Seeds + persists from BUILTIN_SEED on first
-- run (when the file does not yet exist).
local function store_list()
  local f = io.open(SAVE_FILE, "r")
  if f then
    local content = f:read("*a")
    f:close()
    if content and content ~= "" then
      local ok, data = pcall(vim.json.decode, content)
      if ok and type(data) == "table" then
        local out = {}
        for _, a in ipairs(data) do
          if type(a) == "table" and type(a.name) == "string" and type(a.dir) == "string" then
            table.insert(out, { name = a.name, dir = a.dir })
          end
        end
        return out
      end
    end
    return {}
  end
  -- First run: seed from built-ins whose dir exists.
  local seed = {}
  for _, a in ipairs(BUILTIN_SEED) do
    if vim.fn.isdirectory(a.dir) == 1 then
      table.insert(seed, { name = a.name, dir = a.dir })
    end
  end
  persist(seed)
  return seed
end

-- ---------------------------------------------------------------------------
-- Small helpers
-- ---------------------------------------------------------------------------

local function normalize_dir(dir)
  return (vim.fn.fnamemodify(vim.fn.expand(dir), ":p"):gsub("/$", ""))
end

local function name_taken(name, except)
  for _, a in ipairs(store_list()) do
    if a.name == name and a.name ~= except then
      return true
    end
  end
  return false
end

-- Make sure `dir` is a usable directory, offering to create it if missing.
local function ensure_dir(dir)
  if vim.fn.isdirectory(dir) == 1 then
    return true
  end
  if vim.fn.filereadable(dir) == 1 then
    vim.notify("Path exists and is a file, not a directory:\n" .. dir, vim.log.levels.ERROR)
    return false
  end
  local choice = vim.fn.confirm("Directory does not exist:\n" .. dir .. "\n\nCreate it?", "&Yes\n&No", 1)
  if choice ~= 1 then
    return false
  end
  local ok = pcall(vim.fn.mkdir, dir, "p")
  if not ok or vim.fn.isdirectory(dir) == 0 then
    vim.notify("Failed to create " .. dir, vim.log.levels.ERROR)
    return false
  end
  return true
end

-- Guard the destructive on-disk delete: only inside $HOME, never $HOME or root.
local function safe_to_delete(dir)
  local home = vim.fn.expand("~")
  dir = normalize_dir(dir)
  if dir == "" or dir == "/" or dir == home then
    return false
  end
  return vim.startswith(dir, home .. "/")
end

-- ---------------------------------------------------------------------------
-- Switching
-- ---------------------------------------------------------------------------

-- Point the next Claude launch at the given account.
function M.use(acc)
  require("claudecode.terminal").setup(TERM_OPTS, TERM_CMD, { CLAUDE_CONFIG_DIR = acc.dir })
  vim.g.claude_account = acc.name
end

-- Seed the default account (first one whose dir exists) so <leader>cc works
-- before any pick.
function M.apply_default()
  local list = store_list()
  local pick
  for _, a in ipairs(list) do
    if vim.fn.isdirectory(a.dir) == 1 then
      pick = a
      break
    end
  end
  pick = pick or list[1]
  if pick then
    M.use(pick)
  end
end

-- Close any live session and relaunch Claude under `acc`.
local function switch_to(acc, note)
  M.use(acc)
  pcall(vim.cmd, "ClaudeCodeClose") -- end the current session
  vim.cmd("ClaudeCodeOpen") -- relaunch under the chosen account
  vim.notify("Claude account: " .. acc.name .. (note or ""))
end

-- ---------------------------------------------------------------------------
-- Add / rename / delete
-- ---------------------------------------------------------------------------

-- Prompt for a name + config dir, create the dir if missing, persist, then
-- hand the new account to `after`.
local function add_account(after)
  vim.ui.input({ prompt = "New Claude account name: " }, function(name)
    name = name and vim.trim(name) or ""
    if name == "" then
      return
    end
    if name_taken(name, nil) then
      vim.notify("Account '" .. name .. "' already exists", vim.log.levels.WARN)
      return
    end
    vim.ui.input({
      prompt = "Config dir for '" .. name .. "': ",
      default = vim.fn.expand("~/.claude-" .. name),
      completion = "dir",
    }, function(dir)
      dir = dir and vim.trim(dir) or ""
      if dir == "" then
        return
      end
      dir = normalize_dir(dir)
      if not ensure_dir(dir) then
        return
      end
      local list = store_list()
      table.insert(list, { name = name, dir = dir })
      if not persist(list) then
        return
      end
      vim.notify("Added Claude account '" .. name .. "' -> " .. dir)
      if after then
        after({ name = name, dir = dir })
      end
    end)
  end)
end

-- Rename an account and/or repoint its config dir.
local function rename_account(after)
  local list = store_list()
  if #list == 0 then
    vim.notify("No accounts to rename", vim.log.levels.INFO)
    return
  end
  vim.ui.select(list, {
    prompt = "Rename which account?",
    format_item = function(a)
      return a.name .. "  (" .. a.dir .. ")"
    end,
  }, function(sel)
    if not sel then
      return
    end
    vim.ui.input({ prompt = "New name: ", default = sel.name }, function(newname)
      newname = newname and vim.trim(newname) or ""
      if newname == "" then
        return
      end
      if name_taken(newname, sel.name) then
        vim.notify("Account '" .. newname .. "' already exists", vim.log.levels.WARN)
        return
      end
      vim.ui.input({ prompt = "Config dir: ", default = sel.dir, completion = "dir" }, function(newdir)
        newdir = newdir and vim.trim(newdir) or ""
        if newdir == "" then
          return
        end
        newdir = normalize_dir(newdir)
        if newdir ~= sel.dir and not ensure_dir(newdir) then
          return
        end
        local list2 = store_list()
        for _, a in ipairs(list2) do
          if a.name == sel.name and a.dir == sel.dir then
            a.name, a.dir = newname, newdir
          end
        end
        if not persist(list2) then
          return
        end
        if vim.g.claude_account == sel.name then
          vim.g.claude_account = newname
        end
        vim.notify("Renamed '" .. sel.name .. "' -> '" .. newname .. "'")
        if after then
          after()
        end
      end)
    end)
  end)
end

-- Drop an account from the switcher, optionally deleting its dir from disk.
local function delete_account(after)
  local list = store_list()
  if #list == 0 then
    vim.notify("No accounts to delete", vim.log.levels.INFO)
    return
  end
  vim.ui.select(list, {
    prompt = "Delete which account?",
    format_item = function(a)
      return a.name .. "  (" .. a.dir .. ")"
    end,
  }, function(sel)
    if not sel then
      return
    end
    local kept = {}
    for _, a in ipairs(store_list()) do
      if not (a.name == sel.name and a.dir == sel.dir) then
        table.insert(kept, a)
      end
    end
    if not persist(kept) then
      return
    end
    if vim.g.claude_account == sel.name then
      vim.g.claude_account = nil
    end

    local note = " (removed from switcher; dir left on disk)"
    if vim.fn.isdirectory(sel.dir) == 1 and safe_to_delete(sel.dir) then
      local c = vim.fn.confirm(
        "Also delete this directory from disk?\n"
          .. sel.dir
          .. "\n\nThis permanently removes its Claude credentials and settings.",
        "&No, keep it\n&Yes, delete",
        1
      )
      if c == 2 then
        local ok = pcall(vim.fn.delete, sel.dir, "rf")
        note = (ok and vim.fn.isdirectory(sel.dir) == 0)
            and (" (removed and deleted " .. sel.dir .. ")")
          or " (removed from switcher; on-disk delete FAILED)"
      end
    end
    vim.notify("Deleted '" .. sel.name .. "'" .. note)
    if after then
      after()
    end
  end)
end

-- ---------------------------------------------------------------------------
-- Menu
-- ---------------------------------------------------------------------------

-- Open the account manager: switch, add, rename, or delete.
function M.pick()
  local list = store_list()
  local items = {}
  for _, a in ipairs(list) do
    table.insert(items, a)
  end
  table.insert(items, { __action = "add" })
  if #list > 0 then
    table.insert(items, { __action = "rename" })
    table.insert(items, { __action = "delete" })
  end

  vim.ui.select(items, {
    prompt = "Claude accounts:",
    format_item = function(a)
      if a.__action == "add" then
        return "+ Add account..."
      elseif a.__action == "rename" then
        return "~ Rename account..."
      elseif a.__action == "delete" then
        return "x Delete account..."
      end
      local marker = (a.name == vim.g.claude_account) and "* " or "  "
      local missing = (vim.fn.isdirectory(a.dir) == 0) and "  (missing)" or ""
      return marker .. a.name .. "  (" .. a.dir .. ")" .. missing
    end,
  }, function(choice)
    if not choice then
      return
    end
    if choice.__action == "add" then
      -- Switch into the new account right away so its login flow runs and you
      -- can "build" it (a fresh config dir starts unauthenticated).
      add_account(function(acc)
        switch_to(acc, " (log in to finish setup)")
      end)
    elseif choice.__action == "rename" then
      rename_account(function()
        M.pick() -- reopen so the updated list is visible
      end)
    elseif choice.__action == "delete" then
      delete_account(function()
        M.pick()
      end)
    else
      switch_to(choice)
    end
  end)
end

return M
