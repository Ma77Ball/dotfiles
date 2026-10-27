-- Stop the recurring "E325: ATTENTION / found a swap file" prompt, and keep the
-- central swap dir (stdpath("state")/swap) from filling up with orphans left
-- behind when nvim is killed instead of quit (a terminal or zellij pane closed
-- out from under it, a reboot, etc.).
--
-- We decide purely on whether the swap's *owning process is still alive on this
-- machine*:
--   * owner alive  -> open read-only, so two editors never fight over one file;
--   * owner gone    -> delete the orphaned swap and open the file normally.
--
-- We deliberately do NOT key off the swap's recorded host. This laptop's
-- hostname is reassigned by DHCP per network, so a swap written as host "fedora"
-- is later compared against "dhcp-10-9-204-085..." and never matches -- which is
-- what used to make every old swap fall through to nvim's prompt. PID liveness
-- is the right signal on a single machine with a local home. (The one case this
-- is unsafe is a home on shared network storage edited live from two machines at
-- once; that is not this setup.)

local uv = vim.uv or vim.loop

local function owner_alive(pid)
  if type(pid) ~= "number" or pid <= 0 then
    return false
  end
  -- signal 0 only tests for the process's existence; 0 return == alive.
  return uv.kill(pid, 0) == 0
end

vim.api.nvim_create_autocmd("SwapExists", {
  group = vim.api.nvim_create_augroup("stale-swap-reaper", { clear = true }),
  callback = function()
    local ok, info = pcall(vim.fn.swapinfo, vim.v.swapname)
    if not ok or type(info) ~= "table" or info.error ~= nil then
      return -- unreadable swap: leave nvim's normal recovery prompt in place
    end
    if owner_alive(info.pid) then
      vim.v.swapchoice = "o" -- live owner: open read-only
    else
      vim.v.swapchoice = "d" -- stale: delete the swap and edit
    end
  end,
})

-- Sweep the whole swap dir once per session for orphans whose owner is dead,
-- so swaps for files you never happen to reopen don't accumulate forever.
-- Deferred off the startup path so it never slows editor launch.
local function reap_orphans()
  local dir = vim.fn.stdpath("state") .. "/swap"
  local files = vim.fn.glob(dir .. "/*", true, true)
  for _, f in ipairs(files) do
    local ok, info = pcall(vim.fn.swapinfo, f)
    if ok and type(info) == "table" and info.error == nil
       and not owner_alive(info.pid) then
      pcall(os.remove, f)
    end
  end
end

vim.api.nvim_create_autocmd("VimEnter", {
  group = "stale-swap-reaper",
  callback = function()
    vim.defer_fn(function()
      pcall(reap_orphans)
    end, 3000)
  end,
})
