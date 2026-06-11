# msgme

A terminal dashboard for your messages across sources, in the spirit of
[`ghme`](https://github.com/dlvhdr/gh-dash). One TUI with tabbed **sections**, a
scrollable list, a side **preview** pane, and quick actions.

**Sources today:**

| Source | Sections | Actions |
|---|---|---|
| Slack | DMs, Mentions | mark read, reply |
| Microsoft Graph | Mail (Outlook), Teams | mark read (mail), reply (mail + Teams) |
| Google Calendar | Calendar (upcoming events) | read-only |

All sit behind one `sources.Source` interface, so each was added without
touching the TUI.

## How it is built

Mirrors gh-dash's layout:

| Package | Role |
|---|---|
| `internal/config` | XDG YAML config (`~/.config/msgme/config.yml`) |
| `internal/sources` | `Source` interface + the unified `Item` model |
| `internal/sources/slack` | Slack backend (auth, fetch, mark-read, reply) |
| `internal/tui` | Bubbletea model: tabs, list, preview, keybindings |
| `main.go` | entrypoint + subcommands (`init`, `config`, `doctor`) |

Adding a source = a new package under `internal/sources/` that satisfies
`Source`, plus a few lines in `main.go:build()`.

## Install

Requires Go 1.25+.

```sh
make install        # builds and copies to ~/.local/bin/msgme
# make sure ~/.local/bin is on your PATH
```

## Slack setup

msgme uses a Slack **user** OAuth token (`xoxp-...`).

1. Create an app at <https://api.slack.com/apps> ("From scratch").
2. Under **OAuth & Permissions → User Token Scopes**, add:
   - `im:read`, `im:history` (list and read DMs)
   - `channels:history`, `groups:history`, `mpim:history` (messages you are mentioned in)
   - `search:read` (find mentions)
   - `chat:write` (reply)
   - `users:read` (resolve names)
3. **Install to Workspace** and copy the **User OAuth Token** (`xoxp-...`).
4. Provide it to msgme one of two ways:

   ```sh
   export SLACK_TOKEN=xoxp-...        # preferred: keeps it out of disk
   ```

   or run `msgme init` and put it in `~/.config/msgme/config.yml` under `slack.token`.

Verify with:

```sh
msgme doctor
```

## Microsoft setup (Outlook + Teams)

Both come from one Microsoft Graph login.

1. Go to <https://portal.azure.com> → **App registrations** → **New registration**.
   - Supported account types: "Accounts in any org directory and personal
     Microsoft accounts" (tenant `common`).
2. Open the app → **Authentication** → enable **Allow public client flows** (this
   turns on the device-code flow).
3. **API permissions** → **Add a permission** → Microsoft Graph → **Delegated** →
   add: `User.Read`, `Mail.Read`, `Mail.Send`, `Chat.Read`, `ChatMessage.Send`,
   `offline_access`. Then **Grant admin consent** if your account requires it.
4. Copy the **Application (client) ID** into config under `msgraph.clientID`
   (or export `MSGRAPH_CLIENT_ID`), and set `msgraph.enabled: true`.
5. Log in (device-code flow, no redirect needed):

   ```sh
   msgme login ms
   ```

## Google Calendar setup

1. Go to <https://console.cloud.google.com> → **APIs & Services**.
2. **Enable APIs** → enable the **Google Calendar API**.
3. **Credentials** → **Create credentials** → **OAuth client ID** → application
   type **Desktop app** (this permits loopback redirect on any port).
4. Copy the **Client ID** and **Client secret** into config under
   `google.clientID` / `google.clientSecret` (or export `GOOGLE_CLIENT_ID` /
   `GOOGLE_CLIENT_SECRET`), and set `google.enabled: true`.
5. Log in (opens your browser, captures the redirect locally):

   ```sh
   msgme login google
   ```

Tokens are cached under `~/.config/msgme/tokens/` (owner-only) and refresh
automatically; re-run `msgme login <src>` if a token is ever revoked.

## Usage

```
msgme               Launch the dashboard
msgme init          Write a starter config
msgme config        Print the config path
msgme doctor        Show which sources are configured/reachable
msgme login <src>   OAuth login: ms (Outlook+Teams) | google
msgme --help        Help
```

### Keys

| Key | Action |
|---|---|
| `j` / `k` | move down / up |
| `tab` / `shift+tab` | next / prev section |
| `o` | open item in browser/app |
| `m` | mark read |
| `c` | reply (type, `enter` to send, `esc` to cancel) |
| `p` | toggle preview pane |
| `r` | refresh current section |
| `q` | quit |

## Roadmap

- [x] Slack source (DMs + mentions, mark read, reply)
- [x] Microsoft Graph source (Outlook mail **and** Teams from one auth)
- [x] Google Calendar source (upcoming events)
- [ ] Full Slack OAuth flow (drop the manual token step)
- [ ] Teams: mark-chat-read once Graph exposes a delegated endpoint
- [ ] Per-section config + custom keybindings in YAML (like gh-dash)
- [ ] Unified "All" section merging every source by time
