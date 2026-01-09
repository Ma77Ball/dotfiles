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
-- Finally, return the configuration to wezterm: 
return config
