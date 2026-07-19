-- telescope.nvim: fuzzy finder for files, buffers, grep, and help.
return
{
  "nvim-telescope/telescope.nvim",
  version = "*",
  -- Load at startup so this spec's config() runs and sets <leader>ff/<leader>fg.
  -- Without this, remote-nvim listing telescope as a dependency makes lazy.nvim
  -- treat it as lazy=true, and nothing ever triggers loading it.
  lazy = false,
  dependencies = {
    "nvim-lua/plenary.nvim",
    { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
  },
  config = function()
    local telescope = require("telescope")

    telescope.setup({
      defaults = {
        sorting_strategy = "ascending",
        layout_config = {
          prompt_position = "top",
        },
      },
    })

    -- load the native fzf sorter
    pcall(telescope.load_extension, "fzf")

    local builtin = require("telescope.builtin")

    -- Pick the best available file lister so <leader>ff works everywhere,
    -- including remote-nvim sessions on servers without fd/rg (falls back to
    -- plain `find`). Evaluated on whichever machine Neovim runs on.
    local function file_find_command()
      if vim.fn.executable("fd") == 1 then
        return { "fd", "--type", "f", "--hidden", "--follow", "--exclude", ".git" }
      elseif vim.fn.executable("fdfind") == 1 then -- Debian/Ubuntu package name
        return { "fdfind", "--type", "f", "--hidden", "--follow", "--exclude", ".git" }
      elseif vim.fn.executable("rg") == 1 then
        return { "rg", "--files", "--hidden", "--glob", "!.git/*" }
      else
        return { "find", ".", "-type", "f", "-not", "-path", "*/.git/*" }
      end
    end

    -- live_grep needs ripgrep (telescope parses rg's file:line:col output; grep
    -- has no column and would produce broken results). Bail with guidance if a
    -- host lacks it rather than crashing.
    local function grep(extra_args)
      if vim.fn.executable("rg") == 0 then
        vim.notify(
          "live grep needs ripgrep (rg) on this host. Install it:\n"
            .. "  Debian/Ubuntu: sudo apt install ripgrep\n"
            .. "  Fedora/RHEL:   sudo dnf install ripgrep",
          vim.log.levels.ERROR
        )
        return
      end
      builtin.live_grep({ additional_args = extra_args })
    end

    vim.keymap.set("n", "<leader>ff", function()
      builtin.find_files({ find_command = file_find_command() })
    end, { desc = "Find files" })
    vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Switch open buffers" })
    vim.keymap.set("n", "<leader>fr", builtin.oldfiles, { desc = "Recent files" })
    vim.keymap.set("n", "<leader>fg", function()
      grep({ "--ignore-case" })
    end, { desc = "Grep in project (case-insensitive)" })
    vim.keymap.set("n", "<leader>fG", function()
      grep({ "--case-sensitive" })
    end, { desc = "Grep in project (case-sensitive)" })
    vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "Help tags" })
  end,
}

