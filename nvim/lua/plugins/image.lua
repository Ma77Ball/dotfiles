-- image.nvim: inline image rendering via the kitty graphics protocol.
-- Opening a viewable file just shows it:
--   * images -> buffer hijacked and rendered directly
--   * .drawio -> converted to SVG (scripts/drawio_to_svg.py), opened in tabs
--   * video -> a still preview frame (ffmpeg); no inline playback
--   * .pdf -> each page to PNG (pdftoppm) in tabs, or <leader>ob to open externally
-- lazy=false so autocmds register before a command-line file opens.
return {
  {
    "3rd/image.nvim",
    lazy = false,
    build = false, -- skip the `magick` luarock; we use the magick CLI instead
    opts = {
      backend = "kitty",
      processor = "magick_cli",
      -- file patterns auto-rendered via buffer hijack (SVG/BMP added to defaults)
      hijack_file_patterns = {
        "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.avif", "*.svg", "*.bmp",
      },
      integrations = {
        markdown = {
          enabled = true,
          only_render_image_at_cursor = false,
          filetypes = { "markdown", "vimwiki" },
        },
      },
      -- cap rendered size to the window. Keep height < 100 so tall inline
      -- diagrams stay inside the viewport: an image taller than the window is
      -- what makes image.nvim smear/"drag" as you scroll. Use <leader>mz to
      -- see a capped diagram full-size in its own tab.
      max_width_window_percentage = 100,
      max_height_window_percentage = 75,
      window_overlap_clear_enabled = true, -- hide images behind popups/splits
    },
    config = function(_, opts)
      require("image").setup(opts)

      local cache = vim.fn.stdpath("cache") .. "/image-view"
      vim.fn.mkdir(cache, "p")
      local py = vim.fn.exepath("python3")
      if py == "" then py = vim.fn.exepath("python") end
      local converter = vim.fn.stdpath("config") .. "/scripts/drawio_to_svg.py"

      -- .drawio -> render each page to SVG, open in tabs (hijacked as images)
      local function handle_drawio(file, buf)
        if vim.b[buf].autoview_done then return end
        vim.b[buf].autoview_done = true
        if py == "" or vim.fn.filereadable(converter) == 0 then
          vim.notify("drawio view: missing python or converter script", vim.log.levels.WARN)
          return
        end
        vim.schedule(function()
          local out = vim.fn.systemlist({ py, converter, file, "--outdir", cache })
          if vim.v.shell_error ~= 0 then
            vim.notify("drawio convert failed:\n" .. table.concat(out, "\n"), vim.log.levels.ERROR)
            return
          end
          local svgs = vim.fn.glob(cache .. "/" .. vim.fn.fnamemodify(file, ":t:r") .. "-*.svg", false, true)
          table.sort(svgs)
          for _, svg in ipairs(svgs) do
            vim.cmd.tabedit(vim.fn.fnameescape(svg))
          end
          if #svgs > 0 then
            vim.cmd.tabnext(2) -- jump to the first rendered page
            vim.notify(("drawio: rendered %d page(s)"):format(#svgs))
          end
        end)
      end

      -- pdf -> render each page to PNG (pdftoppm) in tabs; <leader>ob opens externally
      local function handle_pdf(file, buf)
        -- bind the browser-open shortcut on the pdf buffer
        vim.keymap.set("n", "<leader>ob", function()
          vim.fn.jobstart({ "xdg-open", file }, { detach = true })
          vim.notify("pdf: opened in browser/viewer (" .. vim.fn.fnamemodify(file, ":t") .. ")")
        end, { buffer = buf, desc = "Open PDF in browser/viewer" })

        if vim.b[buf].autoview_done then return end
        vim.b[buf].autoview_done = true
        if vim.fn.executable("pdftoppm") == 0 then
          vim.notify("pdf view: pdftoppm not found (install poppler), use <leader>ob for browser",
            vim.log.levels.WARN)
          return
        end
        local prefix = cache .. "/" .. vim.fn.fnamemodify(file, ":t:r")
        vim.schedule(function()
          local out = vim.fn.systemlist({ "pdftoppm", "-png", "-r", "150", file, prefix })
          if vim.v.shell_error ~= 0 then
            vim.notify("pdf convert failed:\n" .. table.concat(out, "\n"), vim.log.levels.ERROR)
            return
          end
          local pngs = vim.fn.glob(prefix .. "-*.png", false, true)
          table.sort(pngs)
          for _, png in ipairs(pngs) do
            vim.cmd.tabedit(vim.fn.fnameescape(png))
          end
          if #pngs > 0 then
            vim.cmd.tabnext(2) -- jump to the first rendered page
            vim.notify(("pdf: rendered %d page(s), <leader>ob opens in browser"):format(#pngs))
          end
        end)
      end

      -- video -> extract one preview frame and show it instead of the binary buffer
      local function handle_video(file, buf)
        if vim.b[buf].autoview_done then return end
        vim.b[buf].autoview_done = true
        if vim.fn.executable("ffmpeg") == 0 then return end
        local thumb = cache .. "/" .. vim.fn.fnamemodify(file, ":t") .. ".png"
        vim.schedule(function()
          vim.fn.system({
            "ffmpeg", "-y", "-loglevel", "error", "-i", file,
            "-vf", "thumbnail", "-frames:v", "1", thumb,
          })
          if vim.fn.filereadable(thumb) == 1 then
            vim.cmd.edit(vim.fn.fnameescape(thumb)) -- hijacked & rendered as an image
            vim.notify("video: preview frame (no inline playback — `xdg-open " ..
              vim.fn.fnamemodify(file, ":~") .. "` to play)", vim.log.levels.INFO)
          end
        end)
      end

      local grp = vim.api.nvim_create_augroup("AutoView", { clear = true })
      vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
        group = grp,
        pattern = "*.drawio",
        callback = function(ev) handle_drawio(ev.file, ev.buf) end,
      })
      vim.api.nvim_create_autocmd({ "BufReadPost" }, {
        group = grp,
        pattern = { "*.mp4", "*.mov", "*.webm", "*.mkv", "*.avi" },
        callback = function(ev) handle_video(ev.file, ev.buf) end,
      })
      vim.api.nvim_create_autocmd({ "BufReadPost" }, {
        group = grp,
        pattern = "*.pdf",
        callback = function(ev) handle_pdf(ev.file, ev.buf) end,
      })

      -- sweep buffers already open when this loaded (e.g. command-line file)
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        local name = vim.api.nvim_buf_get_name(buf)
        if name:match("%.drawio$") then
          handle_drawio(name, buf)
        elseif name:match("%.mp4$") or name:match("%.mov$") or name:match("%.webm$")
            or name:match("%.mkv$") or name:match("%.avi$") then
          handle_video(name, buf)
        elseif name:match("%.pdf$") then
          handle_pdf(name, buf)
        end
      end
    end,
  },
}
