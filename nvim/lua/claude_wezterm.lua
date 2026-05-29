-- Custom claudecode.nvim terminal provider.
--
-- Runs Claude in a PERSISTENT wezterm split pane beside nvim:
--   * same wezterm window as nvim (a real split, right side)
--   * a separate process -> claude's high-redraw TUI never touches nvim's single
--     main loop, so the editor-wide input lag of the in-nvim `native` provider is gone
--   * hide/show keeps the SAME claude session alive (we zoom the nvim pane to hide
--     claude, unzoom to show it) -- so <leader>cm always reopens the same conversation
--
-- The claudecode integration (selection send, native diffs, etc.) still works: it
-- rides the in-nvim WebSocket server, and we inject its env into the spawned process.
local M = {}

local claude_pane = nil -- wezterm pane id (string) running claude, or nil
local hidden = false -- whether claude is currently zoomed-away

-- Run `wezterm cli <args...>`; returns trimmed stdout on success, nil on failure.
local function wz(args)
  local cmd = { "wezterm", "cli" }
  vim.list_extend(cmd, args)
  local out = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return vim.trim(out)
end

-- The pane nvim itself is running in (set by wezterm in every pane's env).
local function nvim_pane_id()
  return vim.env.WEZTERM_PANE
end

-- Is `id` still a live pane? (Catches the user closing claude's pane by hand.)
local function pane_alive(id)
  if not id then
    return false
  end
  local out = vim.fn.system({ "wezterm", "cli", "list", "--format", "json" })
  if vim.v.shell_error ~= 0 then
    return false
  end
  local ok, panes = pcall(vim.json.decode, out)
  if not ok or type(panes) ~= "table" then
    return false
  end
  for _, p in ipairs(panes) do
    if tostring(p.pane_id) == tostring(id) then
      return true
    end
  end
  return false
end

-- Drop stale state if claude's pane went away.
local function refresh()
  if claude_pane and not pane_alive(claude_pane) then
    claude_pane = nil
    hidden = false
  end
end

local function split_percent(effective_config)
  local frac = (effective_config and effective_config.split_width_percentage) or 0.40
  return tostring(math.floor(frac * 100))
end

local function spawn(cmd_string, env_table, effective_config, focus)
  local cwd = (effective_config and effective_config.cwd) or vim.fn.getcwd()
  local args = {
    "split-pane",
    "--right",
    "--percent",
    split_percent(effective_config),
    "--cwd",
    cwd,
    "--",
    -- `wezterm cli split-pane` spawns via the mux server, which does NOT inherit the
    -- cli client's env, so the integration env vars must be set explicitly via `env`.
    "env",
  }
  for k, v in pairs(env_table or {}) do
    table.insert(args, string.format("%s=%s", k, v))
  end
  for _, part in ipairs(vim.split(cmd_string, " ", { plain = true, trimempty = true })) do
    table.insert(args, part)
  end

  local id = wz(args)
  if not id or id == "" then
    vim.notify("claude_wezterm: failed to spawn Claude pane", vim.log.levels.ERROR)
    return
  end
  claude_pane = id
  hidden = false
  if not focus then
    local nid = nvim_pane_id()
    if nid then
      wz({ "activate-pane", "--pane-id", nid })
    end
  end
end

-- Bring claude back into view (unzoom is idempotent, so this is safe even if our
-- `hidden` flag drifted out of sync with a wezterm-side hide).
local function show(focus)
  local nid = nvim_pane_id()
  if nid then
    wz({ "zoom-pane", "--pane-id", nid, "--unzoom" })
  end
  hidden = false
  if focus and claude_pane then
    wz({ "activate-pane", "--pane-id", claude_pane })
  end
end

-- Hide claude by zooming the nvim pane to fill the tab; claude keeps running.
local function hide()
  local nid = nvim_pane_id()
  if nid then
    wz({ "activate-pane", "--pane-id", nid })
    wz({ "zoom-pane", "--pane-id", nid, "--zoom" })
  end
  hidden = true
end

function M.setup(_) end

function M.is_available()
  return vim.env.WEZTERM_PANE ~= nil and vim.fn.executable("wezterm") == 1
end

function M.get_active_bufnr()
  return nil -- claude is not an nvim buffer
end

function M.open(cmd_string, env_table, effective_config, focus)
  if focus == nil then
    focus = true
  end
  refresh()
  if claude_pane then
    show(focus)
  else
    spawn(cmd_string, env_table, effective_config, focus)
  end
end

function M.close()
  refresh()
  if claude_pane then
    wz({ "kill-pane", "--pane-id", claude_pane })
    claude_pane = nil
    hidden = false
  end
end

-- <leader>cc: toggle claude's visibility (keeps the session running when hidden).
function M.simple_toggle(cmd_string, env_table, effective_config)
  refresh()
  if not claude_pane then
    spawn(cmd_string, env_table, effective_config, true)
  elseif hidden then
    show(true)
  else
    hide()
  end
end

-- <leader>cm: "jump to or open" -> always bring up + focus the SAME session.
function M.focus_toggle(cmd_string, env_table, effective_config)
  refresh()
  if not claude_pane then
    spawn(cmd_string, env_table, effective_config, true)
  else
    show(true)
  end
end

return M
