-- remote-nvim: VSCode "Remote-SSH"-style remote development.
--
-- Neovim runs ON the remote host, so its tools, LSP servers, compilers and
-- filesystem are the machine's, not yours. Your local Neovim config is copied
-- over and installed there, so it still looks and behaves like your setup.
-- Connects via ~/.ssh/config and supports username+password auth (it prompts;
-- no SSH key or sshpass required). First connect to a host downloads Neovim
-- and installs your plugins on the server, so it takes a minute; later ones are
-- fast.
--
-- <leader>sh is the plain remote-nvim picker (unchanged). A fresh server is
-- missing things the copied config needs, so run <leader>sc (RemoteProvision)
-- ONCE per host, before connecting, to set them all up:
--   * your Claude skills (remote-nvim copies your nvim config but NOT ~/.claude)
--   * ripgrep + fd            -> telescope <leader>ff / <leader>fg
--   * lazygit                 -> <leader>gg
--   * git + a C toolchain     -> treesitter / fzf-native compile on first launch
-- Credentials are never synced -- run `claude` once on the server to log in.
return {
  {
    "amitds1997/remote-nvim.nvim",
    version = "*",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-telescope/telescope.nvim",
    },
    keys = {
      { "<leader>sh", "<cmd>RemoteStart<cr>", desc = "Remote: start SSH session" },
      { "<leader>ss", "<cmd>RemoteStop<cr>", desc = "Remote: stop session" },
      { "<leader>si", "<cmd>RemoteInfo<cr>", desc = "Remote: session info" },
      { "<leader>sc", "<cmd>RemoteProvision<cr>", desc = "Remote: provision host (skills + tools)" },
    },
    config = function()
      require("remote-nvim").setup({
        ssh_config = {
          ssh_binary = "ssh",
          scp_binary = "scp",
          ssh_config_file_paths = { "$HOME/.ssh/config" },
        },
      })

      -- The remote-side install script. Written to a file and run there, so it
      -- can use any quoting freely (no ssh/shell quote-nesting to worry about).
      -- Installs everything the copied config needs, best-effort, across the
      -- common package managers, with a GitHub-release fallback for lazygit
      -- (which Debian/Ubuntu don't package in apt).
      local install_script = {
        "#!/usr/bin/env bash",
        'echo "==> Installing tools (ripgrep, fd, lazygit, git, compiler, curl)…"',
        "if command -v apt-get >/dev/null 2>&1; then",
        "  sudo apt-get update",
        "  sudo apt-get install -y ripgrep fd-find git build-essential curl",
        "  sudo apt-get install -y lazygit || true",
        "elif command -v dnf >/dev/null 2>&1; then",
        "  sudo dnf install -y ripgrep fd-find git gcc gcc-c++ make curl",
        "  sudo dnf install -y lazygit || true",
        "elif command -v pacman >/dev/null 2>&1; then",
        "  sudo pacman -Sy --noconfirm ripgrep fd git base-devel curl",
        "  sudo pacman -S --noconfirm lazygit || true",
        "elif command -v zypper >/dev/null 2>&1; then",
        "  sudo zypper install -y ripgrep fd git gcc make curl",
        "  sudo zypper install -y lazygit || true",
        "elif command -v apk >/dev/null 2>&1; then",
        "  sudo apk add ripgrep fd git build-base curl",
        "  sudo apk add lazygit || true",
        "else",
        '  echo "No known package manager; install ripgrep, fd, lazygit, git manually."',
        "fi",
        "",
        "# lazygit is often not in distro repos -- fall back to the release binary.",
        "if ! command -v lazygit >/dev/null 2>&1; then",
        '  echo "==> Fetching lazygit from GitHub releases…"',
        "  arch=$(uname -m)",
        '  case "$arch" in',
        "    x86_64) lgarch=x86_64 ;;",
        "    aarch64|arm64) lgarch=arm64 ;;",
        "    armv*) lgarch=armv6 ;;",
        "    *) lgarch=$arch ;;",
        "  esac",
        "  url=$(curl -fsSL -o /dev/null -w '%{url_effective}' https://github.com/jesseduffield/lazygit/releases/latest)",
        "  ver=${url##*/v}",
        '  if [ -n "$ver" ] && curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/v${ver}/lazygit_${ver}_Linux_${lgarch}.tar.gz" -o /tmp/lazygit.tar.gz; then',
        "    tar -xzf /tmp/lazygit.tar.gz -C /tmp lazygit",
        "    sudo install /tmp/lazygit /usr/local/bin/lazygit",
        "    rm -f /tmp/lazygit.tar.gz /tmp/lazygit",
        '    echo "==> lazygit installed to /usr/local/bin"',
        "  else",
        '    echo "!! Could not fetch lazygit; install it manually."',
        "  fi",
        "fi",
        "",
        'echo "==> Installed:"',
        'for b in rg fd fdfind lazygit git cc make curl; do command -v "$b" >/dev/null 2>&1 && echo "   ok: $b"; done',
        'echo "==> Now run \\`claude\\` on the server once to log in, then <leader>sh."',
      }

      -- Provision `host`: rsync Claude skills up, copy the install script up,
      -- then run it with a TTY (for sudo). One shared SSH connection
      -- (ControlMaster) so you authenticate at most once. Runs in a terminal
      -- split so any password/sudo prompt is interactive.
      local function provision(host)
        if not host or host == "" then
          return
        end
        for _, bin in ipairs({ "rsync", "scp", "ssh" }) do
          if vim.fn.executable(bin) == 0 then
            vim.notify(bin .. " not found locally", vim.log.levels.ERROR)
            return
          end
        end

        local local_script = vim.fn.stdpath("cache") .. "/remote-provision.sh"
        vim.fn.writefile(install_script, local_script)

        -- Reuse one connection across rsync/scp/ssh.
        local sshopts = "-o ControlMaster=auto -o ControlPath="
          .. vim.fn.expand("~") .. "/.ssh/cm-%r@%h:%p -o ControlPersist=120"
        local host_esc = vim.fn.shellescape(host)

        local steps = {}

        -- 1) Claude skills.
        local base = vim.fn.expand("~/.claude")
        local srcs = {}
        for _, p in ipairs({ "CLAUDE.md", "settings.json", "skills", "plugins", "commands", "agents" }) do
          if vim.loop.fs_stat(base .. "/" .. p) then
            table.insert(srcs, vim.fn.shellescape(base .. "/./" .. p)) -- "/./" anchors --relative
          end
        end
        if #srcs > 0 then
          table.insert(steps, 'echo "==> Syncing Claude skills…"')
          table.insert(steps, ('rsync -az --relative --mkpath -e "ssh %s" %s %s'):format(
            sshopts, table.concat(srcs, " "), vim.fn.shellescape(host .. ":.claude/")))
        end

        -- 2) Copy the install script up and run it (TTY for sudo).
        table.insert(steps, ("scp %s %s %s"):format(
          sshopts, vim.fn.shellescape(local_script), vim.fn.shellescape(host .. ":remote-provision.sh")))
        table.insert(steps, ("ssh %s -t %s bash remote-provision.sh"):format(sshopts, host_esc))

        local full = table.concat(steps, " && ")

        vim.cmd("botright 20split | enew")
        local buf = vim.api.nvim_get_current_buf()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {}) -- jobstart(term) needs empty+unmodified
        vim.bo[buf].modified = false
        vim.notify("Provisioning " .. host .. " (Claude skills + tools)…")
        vim.fn.jobstart({ "bash", "-lc", full }, {
          term = true,
          on_exit = function(_, code)
            vim.schedule(function()
              if code == 0 then
                vim.notify("Provisioned " .. host .. ". Connect with <leader>sh.")
              else
                vim.notify("Provision of " .. host .. " exited with code " .. code, vim.log.levels.WARN)
              end
            end)
          end,
        })
        vim.cmd("startinsert")
      end

      vim.api.nvim_create_user_command("RemoteProvision", function(o)
        if o.args ~= "" then
          provision(o.args)
        else
          vim.ui.input({ prompt = "Provision host (user@host or ssh alias): " }, function(h)
            if h and h ~= "" then
              provision(vim.trim(h))
            end
          end)
        end
      end, { nargs = "?", desc = "Sync Claude skills + install ripgrep/fd/lazygit/git/toolchain on a host" })
    end,
  },
}
