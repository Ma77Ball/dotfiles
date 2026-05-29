local wezterm = require("wezterm") 
-- This will hold the configuration. 
local config = wezterm.config_builder() 
-- Defines action commands 
local act = wezterm.action 
-- This is where you actually apply your config choices. 
-- For example, changing the initial geometry for new windows: 
config.initial_cols = 120 
config.initial_rows = 28 
-- or, changing the font size and color scheme.
config.font_size = 12 
config.color_scheme = "AdventureTime" 
config.mouse_bindings = {       
-- Change the default click behavior so that it only selects       
-- text and doesn't open hyperlinks       
{             
event = { Up = { streak = 1, button = "Left" } },             
mods = "NONE",             
action = act.CompleteSelection("ClipboardAndPrimarySelection"),       
},       
-- and make CTRL-Click open hyperlinks       
{             
event = { Up = { streak = 1, button = "Left" } },
mods = "CTRL",             
action = act.OpenLinkAtMouseCursor,       
},       
-- NOTE that binding only the 'Up' event can give unexpected behaviors.       
-- Read more below on the gotcha of binding an 'Up' event only. 
} 
-- tabs 
config.use_fancy_tab_bar = false 
config.tab_bar_at_bottom = true 
config.enable_tab_bar = true 
config.hide_tab_bar_if_only_one_tab = true 
config.tab_max_width = 50 
-- add opacity 
config.window_background_opacity = 0.9 
config.text_background_opacity = 1 
-- wayland issue check 
config.enable_wayland = false 
-- ── nvim <-> wezterm pane navigation + Claude pane commands ──────────────────
-- <C-h/j/k/l> move between wezterm panes; but when the focused pane is running
-- nvim we forward the key to nvim instead, so nvim's own smart-splits handles the
-- move (and hands back off to wezterm at its edges). This makes the Claude split
-- navigate exactly like a native nvim split.
-- Prefer the IS_NVIM user var that smart-splits.nvim broadcasts (reliable even when
-- nvim runs under a wrapper); fall back to matching the foreground process name.
local function is_nvim(pane)
  local vars = pane.get_user_vars and pane:get_user_vars() or nil
  if vars and vars.IS_NVIM == "true" then
    return true
  end
  local proc = pane:get_foreground_process_name() or ""
  return proc:find("nvim", 1, true) ~= nil
end

-- The nvim ("code") pane in this tab, when called from the Claude pane. Targets the
-- pane actually running nvim, falling back to any other pane in a 2-pane layout.
local function code_pane_id(pane)
  local tab = pane:tab()
  if not tab then
    return nil
  end
  local other
  for _, p in ipairs(tab:panes()) do
    if p:pane_id() ~= pane:pane_id() then
      other = other or p:pane_id()
      if is_nvim(p) then
        return p:pane_id()
      end
    end
  end
  return other
end

-- A <C-dir> key: forward to nvim if nvim is focused, else move wezterm panes.
local function nav(dir, key)
  return wezterm.action_callback(function(win, pane)
    if is_nvim(pane) then
      win:perform_action(act.SendKey({ key = key, mods = "CTRL" }), pane)
    else
      win:perform_action(act.ActivatePaneDirection(dir), pane)
    end
  end)
end

config.keys = {
  { key = "h", mods = "CTRL", action = nav("Left", "h") },
  { key = "j", mods = "CTRL", action = nav("Down", "j") },
  { key = "k", mods = "CTRL", action = nav("Up", "k") },
  { key = "l", mods = "CTRL", action = nav("Right", "l") },

  -- Ctrl-x: from the Claude pane, jump back to code but LEAVE Claude open beside it.
  -- In nvim, pass Ctrl-x through untouched.
  {
    key = "x",
    mods = "CTRL",
    action = wezterm.action_callback(function(win, pane)
      if is_nvim(pane) then
        win:perform_action(act.SendKey({ key = "x", mods = "CTRL" }), pane)
      else
        win:perform_action(act.ActivatePaneDirection("Left"), pane)
      end
    end),
  },

  -- Ctrl-q: from the Claude pane, HIDE Claude (zoom the code pane to fill the tab --
  -- the Claude session keeps running) and jump back to code. In nvim, pass through.
  -- Re-open the same session with <leader>cm.
  {
    key = "q",
    mods = "CTRL",
    action = wezterm.action_callback(function(win, pane)
      if is_nvim(pane) then
        win:perform_action(act.SendKey({ key = "q", mods = "CTRL" }), pane)
        return
      end
      local nvim_id = code_pane_id(pane)
      if nvim_id then
        wezterm.run_child_process({ "wezterm", "cli", "activate-pane", "--pane-id", tostring(nvim_id) })
        wezterm.run_child_process({ "wezterm", "cli", "zoom-pane", "--pane-id", tostring(nvim_id), "--zoom" })
      end
    end),
  },
}

-- Finally, return the configuration to wezterm:
return config
