-- Rebuild the working layout (Neo-tree sidebar + Claude Code window) after a
-- reboot, so reopening the terminal lands you back where you were.
--
-- Zellij resurrects a session's panes after a reboot, but it serializes an nvim
-- pane in one of two shapes, and both need handling:
--
--   1. `pane command="nvim"`  (nvim launched bare, with no file argument)
--      Zellij's post_command_discovery_hook rewrites this on resurrection to
--          env NVIM_RESTORE_LAYOUT=1 nvim
--      i.e. a clean nvim in the pane's real cwd, carrying this marker. See the
--      hook note in dotfiles/zellij/config.kdl.
--
--   2. `pane edit="..."`      (nvim launched on a path, e.g. `nvim .`)
--      Zellij records this as an editor pane and rebuilds its absolute path by
--      concatenating the cwd twice (e.g. .../Local_AI_Work/Projects/.../Local_AI_Work/.),
--      a path that never exists. The discovery hook canNOT rewrite `edit=` panes,
--      so these resurrect as `nvim <doubled-bogus-path>` with NO marker. We detect
--      that bogus path directly (ends in "/." and does not exist) and treat it the
--      same as a marked restore, dropping the junk buffer first.
--
-- When nvim sees either case (and nothing else) it recreates the layout you
-- normally build by hand:
--   * <leader>pv -> Neo-tree filesystem sidebar on the left
--   * <leader>cc -> Claude Code window on the right (on the account last used in
--                   this folder, handled in lua/claude_accounts.lua)
--
-- Plain `nvim` launches, `nvim <real-file>`, `nvim <real-dir>`, git commit
-- buffers, diff mode, etc. match neither case, so everyday editing is unchanged.

local argc = vim.fn.argc(-1)
local arg0 = (argc >= 1) and vim.fn.argv(0) or nil

-- True for zellij's doubled, non-existent `edit=` path: it ends in "/." and is
-- neither a real file nor a real directory. A real `nvim dir/.` is excluded
-- because nvim normalizes it (strips the "/.") and isdirectory() is true; a real
-- `nvim newfile` is excluded because it does not end in "/.".
local function is_zellij_bogus_path(a)
  if not a or a == "" or not a:match("/%.$") then
    return false
  end
  return vim.fn.isdirectory(a) == 0 and vim.fn.filereadable(a) == 0
end

local marked = (vim.env.NVIM_RESTORE_LAYOUT == "1") and argc == 0
local edit_restore = (argc == 1) and is_zellij_bogus_path(arg0)

if not (marked or edit_restore) then
  return
end

-- For the `edit=` case the bogus path is already (about to be) the first buffer.
-- Clearing the arglist in init stops nvim treating it as files to edit; we still
-- wipe the leftover buffer in the VimEnter handler below.
if edit_restore then
  pcall(vim.cmd, "silent! %argdelete")
end

vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    -- Drop the marker so any child process (the Claude terminal, a nested nvim
    -- opened for a git commit, :terminal, ...) does not inherit it and re-fire.
    vim.env.NVIM_RESTORE_LAYOUT = nil

    -- Defer until the UI has settled so the splits lay out predictably.
    vim.schedule(function()
      -- Replace zellij's bogus doubled-path buffer with a clean empty one.
      if edit_restore then
        local bad = vim.api.nvim_get_current_buf()
        pcall(vim.cmd, "enew")
        pcall(vim.api.nvim_buf_delete, bad, { force = true })
      end

      local editor_win = vim.api.nvim_get_current_win()

      -- Left: Neo-tree filesystem sidebar (loaded eagerly; keeps focus here).
      pcall(vim.cmd, "Neotree filesystem show")

      -- Right: Claude Code window. claudecode.nvim is lazy-loaded on its keys,
      -- so pull it in first; loading it runs its setup(), which applies the
      -- account last used in this folder before the terminal launches.
      pcall(function()
        require("lazy").load({ plugins = { "claudecode.nvim" } })
      end)
      pcall(vim.cmd, "ClaudeCodeOpen")

      -- Hand focus back to the editor so you don't start inside the Claude prompt.
      if vim.api.nvim_win_is_valid(editor_win) then
        pcall(vim.api.nvim_set_current_win, editor_win)
      end
    end)
  end,
})
