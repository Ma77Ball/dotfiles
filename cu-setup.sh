#!/usr/bin/env bash
# =============================================================================
# cu-setup.sh - rebuild SSH access + a full dev env on a fresh Texera
# computing unit (unprivileged uid 1001, ephemeral overlayfs HOME, NO ROOT).
#
# Run it ON the CU. Two ways:
#   1) Paste the base64 one-liner (see cu-setup.b64.txt) into the CU web terminal.
#   2) Or: curl -fsSL https://raw.githubusercontent.com/Ma77Ball/dotfiles/main/cu-setup.sh | bash
#
# Everything installs under $HOME. Nothing needs root. On CU restart the
# overlayfs HOME is wiped, so just run this again. Durable fix = bake into image.
#
# -----------------------------------------------------------------------------
# HOW SSH ACCESS WORKS (read this before running):
#
# This does NOT expose a public port. The CU joins your Tailscale tailnet and
# runs an SSH server (dropbear) on port 2222. You can then reach it ONLY from a
# machine that is BOTH:
#   (a) logged into the SAME tailnet, AND
#   (b) whose PUBLIC key is listed in AUTHORIZED_KEYS below (pubkey-only auth).
#
# To let a machine (laptop, desktop) connect, add ITS public key:
#   1. On that machine:   cat ~/.ssh/id_ed25519.pub
#        (no such file? run:  ssh-keygen -t ed25519   then re-run the cat)
#   2. Paste the whole line into AUTHORIZED_KEYS below (one key per line, inside
#      the quotes). Keep as many keys as you want, each on its own line.
#   3. Make sure that machine is on the tailnet:  tailscale up   (install from
#      https://tailscale.com/download if needed) and log into the same account.
#
# After this script runs it prints the CU's Tailscale IP. Connect with:
#   ssh -p 2222 texera@<that-tailscale-ip>
# (A public key here is safe to commit; only the matching PRIVATE key can log in
#  and that never leaves your machine.)
# -----------------------------------------------------------------------------
set -u

# --- authorized SSH keys (machines allowed to ssh into this CU) ---------------
# One public key per line, inside the quotes. See the notes above for how to
# grab a machine's key (cat ~/.ssh/id_ed25519.pub) and add it here.
AUTHORIZED_KEYS='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJDMMxCZTcTMp3v3X+EO5l3Ph+vNLI5OfNgXjZOFVZYu fedora-2
# ssh-ed25519 AAAA...your-laptop-key... laptop
'

ARCH_TS=amd64; ARCH_RS=x86_64
DOTFILES_URL="https://github.com/Ma77Ball/dotfiles"
HOSTNAME_TS="$(hostname)"
mkdir -p ~/bin ~/opt ~/ts ~/ts-state ~/.ssh; chmod 700 ~/.ssh
export PATH="$HOME/bin:$PATH" LANG=C.UTF-8 LC_ALL=C.UTF-8
export LD_LIBRARY_PATH="$HOME/dropbear/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"
ok(){ command -v "$1" >/dev/null 2>&1; }
gh_latest(){ curl -fsSL "https://api.github.com/repos/$1/releases/latest" | grep -oE '"tag_name": *"[^"]+"' | head -1 | sed 's/.*"tag_name": *"//;s/"//'; }
say(){ printf '\n== %s ==\n' "$*"; }

# --- 1. Tailscale (userspace, no TUN, no root) -------------------------------
say "Tailscale"
if [ ! -x ~/ts/tailscaled ]; then
  curl -fsSL "https://pkgs.tailscale.com/stable/tailscale_latest_${ARCH_TS}.tgz" -o ~/ts.tgz
  tar -xzf ~/ts.tgz -C ~/ts --strip-components=1 && rm -f ~/ts.tgz
fi
if ! pgrep -f 'tailscaled --tun=userspace' >/dev/null 2>&1; then
  nohup ~/ts/tailscaled --tun=userspace-networking --socket="$HOME/tailscaled.sock" \
        --statedir="$HOME/ts-state" >~/tsd.log 2>&1 & disown
  sleep 2
fi
ln -sf ~/ts/tailscale ~/bin/tailscale
# 'up' prints a login URL on a fresh CU; reconnects silently if state persisted.
~/ts/tailscale --socket="$HOME/tailscaled.sock" up --hostname="$HOSTNAME_TS" || true
echo "Tailscale IP: $(~/ts/tailscale --socket="$HOME/tailscaled.sock" ip -4 2>/dev/null)"

# --- 2. Dropbear SSH server on :2222 (pubkey-only, no root) -------------------
say "Dropbear SSH server (port 2222)"
if [ ! -x ~/dropbear/usr/sbin/dropbear ]; then
  cd ~ && apt-get download dropbear-bin libtomcrypt1 libtommath1 2>/dev/null
  for d in dropbear-bin_*.deb libtomcrypt1_*.deb libtommath1_*.deb; do
    [ -f "$d" ] && dpkg-deb -x "$d" ~/dropbear; done
  rm -f dropbear-bin_*.deb libtomcrypt1_*.deb libtommath1_*.deb
fi
printf '%s\n' "$AUTHORIZED_KEYS" > ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys
[ -f ~/dbkey ] || ~/dropbear/usr/bin/dropbearkey -t ed25519 -f ~/dbkey >/dev/null 2>&1
if ! pgrep -f 'dropbear -E' >/dev/null 2>&1; then
  nohup ~/dropbear/usr/sbin/dropbear -E -s -p 2222 -r ~/dbkey >~/db.log 2>&1 & disown
fi
echo "Dropbear listening on :2222, connect with ssh -p 2222 texera@<tailscale-ip>"

# --- 3. Neovim (prebuilt, no root) -------------------------------------------
say "Neovim"
if [ ! -x ~/bin/nvim ]; then
  cd ~ && curl -fsSL -o nvim.tgz https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz \
    || curl -fsSL -o nvim.tgz https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz
  tar -xzf nvim.tgz && rm -f nvim.tgz
  D=$(ls -d nvim-linux*/ | head -1); ln -sf ~/"${D}"bin/nvim ~/bin/nvim
fi
~/bin/nvim --version | head -1

# --- 4. CLI tools: node, ripgrep, fd, fzf, lazygit ---------------------------
say "CLI tools"
if ! ok node; then
  nv=$(curl -fsSL https://nodejs.org/dist/index.json | tr '}' '\n' | grep -m1 '"lts":"' | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  curl -fsSL -o node.txz "https://nodejs.org/dist/${nv}/node-${nv}-linux-x64.tar.xz" \
    && tar -xJf node.txz -C ~/opt && rm -f node.txz \
    && for b in node npm npx; do ln -sf ~/opt/node-${nv}-linux-x64/bin/$b ~/bin/$b; done
fi
if ! ok rg; then v=$(gh_latest BurntSushi/ripgrep); cd /tmp
  curl -fsSL -o rg.tgz "https://github.com/BurntSushi/ripgrep/releases/download/${v}/ripgrep-${v}-${ARCH_RS}-unknown-linux-musl.tar.gz" \
    && tar -xzf rg.tgz && cp ripgrep-*/rg ~/bin/ && rm -rf ripgrep-* rg.tgz; fi
if ! ok fd; then v=$(gh_latest sharkdp/fd); cd /tmp
  curl -fsSL -o fd.tgz "https://github.com/sharkdp/fd/releases/download/${v}/fd-${v}-${ARCH_RS}-unknown-linux-musl.tar.gz" \
    && tar -xzf fd.tgz && cp fd-*/fd ~/bin/ && rm -rf fd-* fd.tgz; fi
if ! ok fzf; then v=$(gh_latest junegunn/fzf); vn=${v#v}; cd /tmp
  curl -fsSL -o fzf.tgz "https://github.com/junegunn/fzf/releases/download/${v}/fzf-${vn}-linux_amd64.tar.gz" \
    && tar -xzf fzf.tgz && cp fzf ~/bin/ && rm -f fzf.tgz; fi
if ! ok lazygit; then v=$(gh_latest jesseduffield/lazygit); vn=${v#v}; cd /tmp
  curl -fsSL -o lg.tgz "https://github.com/jesseduffield/lazygit/releases/download/${v}/lazygit_${vn}_Linux_x86_64.tar.gz" \
    && tar -xzf lg.tgz lazygit && cp lazygit ~/bin/ && rm -f lg.tgz lazygit; fi
python3 -m pip install --user -q pynvim 2>/dev/null || true

# --- 5. Claude Code ----------------------------------------------------------
say "Claude Code"
npm install -g @anthropic-ai/claude-code >/dev/null 2>&1
cbin=$(ls ~/opt/node-*/bin/claude 2>/dev/null | head -1); [ -n "$cbin" ] && ln -sf "$cbin" ~/bin/claude
~/bin/claude --version 2>&1 | head -1

# --- 6. Nvim config from dotfiles (public repo) ------------------------------
say "Nvim config"
rm -rf ~/dotfiles-repo
git clone --depth 1 "$DOTFILES_URL" ~/dotfiles-repo >/dev/null 2>&1
rm -rf ~/.config/nvim && mkdir -p ~/.config && cp -r ~/dotfiles-repo/nvim ~/.config/nvim
timeout 300 ~/bin/nvim --headless "+Lazy! restore" +qa >/dev/null 2>&1
timeout 120 ~/bin/nvim --headless "+Lazy! install" +qa >/dev/null 2>&1

# --- 7. Mason LSPs / DAP tools ----------------------------------------------
say "Mason LSPs"
timeout 600 ~/bin/nvim --headless \
  -c "Lazy! load mason.nvim mason-lspconfig.nvim mason-tool-installer.nvim" \
  -c "lua require('mason').setup()" \
  -c "MasonInstall lua-language-server pyright ruff typescript-language-server html-lsp debugpy js-debug-adapter java-debug-adapter java-test" \
  -c "qa" >/dev/null 2>&1

# --- 8. Persist PATH + UTF-8 locale for interactive shells -------------------
BLOCK='# >>> nvim-env >>>
export PATH="$HOME/bin:$PATH"
export LANG=C.UTF-8 LC_ALL=C.UTF-8
# >>> end nvim-env >>>'
for f in ~/.profile ~/.bashrc; do touch "$f"; grep -q nvim-env "$f" || printf '\n%s\n' "$BLOCK" >> "$f"; done

say "DONE"
TS_IP="$(~/ts/tailscale --socket="$HOME/tailscaled.sock" ip -4 2>/dev/null)"
echo "Tailscale IP : ${TS_IP:-<not up yet - re-check with: ~/ts/tailscale --socket=\$HOME/tailscaled.sock ip -4>}"
echo "Connect from a machine that is (1) on this tailnet and (2) whose pubkey is"
echo "in AUTHORIZED_KEYS at the top of this script:"
echo "    ssh -p 2222 texera@${TS_IP:-<tailscale-ip>}      then run:  nvim   or   claude"
echo "Currently authorized keys on this CU:"
sed 's/^/    /' ~/.ssh/authorized_keys 2>/dev/null | grep -v '^ *#' | grep -v '^ *$'
