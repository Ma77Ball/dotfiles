// Command msgme is a terminal dashboard of your messages across sources
// (Slack today; Outlook, Google Calendar, and Microsoft Teams planned),
// modeled on the structure of ghme/gh-dash.
package main

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"time"

	"github.com/Ma77Ball/msgme/internal/auth"
	"github.com/Ma77Ball/msgme/internal/config"
	"github.com/Ma77Ball/msgme/internal/sources"
	"github.com/Ma77Ball/msgme/internal/sources/gcal"
	"github.com/Ma77Ball/msgme/internal/sources/msgraph"
	"github.com/Ma77Ball/msgme/internal/sources/slack"
	"github.com/Ma77Ball/msgme/internal/tui"
	tea "github.com/charmbracelet/bubbletea"
)

const usage = `msgme - your messages in a terminal UI

USAGE
  msgme               Launch the dashboard
  msgme init          Write a starter config to ~/.config/msgme/config.yml
  msgme config        Print the resolved config path
  msgme doctor        Check which sources are configured and reachable
  msgme login <src>   Interactive OAuth login: ms (Outlook+Teams) | google
  msgme --help        Show this help

SOURCES
  slack    Slack DMs + mentions        (set SLACK_TOKEN; no login flow needed)
  ms       Outlook mail + Teams chats  (msgme login ms)
  google   Google Calendar             (msgme login google)

CONFIG
  ~/.config/msgme/config.yml   (override dir with XDG_CONFIG_HOME)
  Tokens cached under ~/.config/msgme/tokens/ (owner-only).

KEYS (in the TUI)
  j/k move   tab/shift-tab section   o open   m mark read   c reply
  p toggle preview   r refresh   q quit
`

func main() {
	args := os.Args[1:]
	if len(args) > 0 {
		switch args[0] {
		case "-h", "--help", "help":
			fmt.Print(usage)
			return
		case "init":
			runInit()
			return
		case "config":
			fmt.Println(config.Path())
			return
		case "doctor":
			runDoctor()
			return
		case "login":
			runLogin(args[1:])
			return
		default:
			fmt.Fprintf(os.Stderr, "msgme: unknown command %q\n\n%s", args[0], usage)
			os.Exit(2)
		}
	}
	runTUI()
}

func runInit() {
	path, created, err := config.WriteDefault()
	if err != nil {
		fail(err)
	}
	if created {
		fmt.Printf("wrote starter config: %s\n", path)
	} else {
		fmt.Printf("config already exists: %s\n", path)
	}
}

// build returns the connected sources from config, plus any setup errors keyed
// by source name (so callers can attach the message to that source's tab).
func build(ctx context.Context, cfg config.Config) ([]sources.Source, map[string]error) {
	var srcs []sources.Source
	warns := map[string]error{}
	if cfg.Slack.Enabled {
		if s, err := slack.New(cfg.Slack.Token, cfg.Slack.Sections); err != nil {
			warns["slack"] = err
		} else {
			srcs = append(srcs, s)
		}
	}
	if cfg.MSGraph.Enabled {
		if s, err := msgraph.New(ctx, cfg.MSGraph.ClientID, cfg.MSGraph.Tenant, cfg.MSGraph.Sections); err != nil {
			warns["msgraph"] = err
		} else {
			srcs = append(srcs, s)
		}
	}
	if cfg.Google.Enabled {
		if s, err := gcal.New(ctx, cfg.Google.ClientID, cfg.Google.ClientSecret, cfg.Google.Sections); err != nil {
			warns["gcal"] = err
		} else {
			srcs = append(srcs, s)
		}
	}
	return srcs, warns
}

// setupTabs returns a placeholder tab for every known provider that did not
// connect, so the dashboard always shows one tab per app (like gh-dash). When a
// provider was enabled but errored, its real error is shown above the generic
// instructions.
func setupTabs(srcs []sources.Source, warns map[string]error) []sources.Section {
	have := map[string]bool{}
	for _, s := range srcs {
		have[s.Name()] = true
	}
	var tabs []sources.Section
	add := func(name string, tab sources.Section) {
		if have[name] {
			return
		}
		if err := warns[name]; err != nil {
			tab.Setup = "⚠ " + err.Error() + "\n\n" + tab.Setup
		}
		tabs = append(tabs, tab)
	}
	add("slack", slack.SetupTab())
	add("msgraph", msgraph.SetupTab())
	add("gcal", gcal.SetupTab())
	return tabs
}

// runLogin runs the interactive OAuth flow for a source and caches the token.
func runLogin(args []string) {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "usage: msgme login <ms|google|slack>")
		os.Exit(2)
	}
	cfg, err := config.Load()
	if err != nil {
		fail(err)
	}
	ctx := context.Background()
	switch args[0] {
	case "ms", "msgraph", "outlook", "teams":
		if cfg.MSGraph.ClientID == "" {
			fail(fmt.Errorf("set msgraph.clientID in config (or MSGRAPH_CLIENT_ID) first; see README"))
		}
		if err := auth.DeviceLogin(ctx, msgraph.Name, msgraph.Config(cfg.MSGraph.ClientID, cfg.MSGraph.Tenant)); err != nil {
			fail(err)
		}
	case "google", "gcal", "calendar":
		if cfg.Google.ClientID == "" {
			fail(fmt.Errorf("set google.clientID/clientSecret in config (or env) first; see README"))
		}
		if err := auth.LoopbackLogin(ctx, gcal.Name, gcal.Config(cfg.Google.ClientID, cfg.Google.ClientSecret), openBrowser); err != nil {
			fail(err)
		}
	case "slack":
		fmt.Println("Slack uses a token, not an OAuth login. Export SLACK_TOKEN (see README).")
	default:
		fail(fmt.Errorf("unknown source %q (use: ms | google | slack)", args[0]))
	}
}

// openBrowser opens a URL in the user's browser for the loopback login flow.
func openBrowser(url string) {
	bin := os.Getenv("BROWSER")
	if bin == "" {
		bin = "xdg-open"
	}
	c := exec.Command(bin, url)
	_ = c.Start()
	go func() { _ = c.Wait() }()
}

func runDoctor() {
	cfg, err := config.Load()
	if err != nil {
		fail(err)
	}
	fmt.Printf("config: %s\n", config.Path())
	srcs, warns := build(context.Background(), cfg)
	for _, w := range warns {
		fmt.Printf("  ! %v\n", w)
	}
	if len(srcs) == 0 {
		fmt.Println("  no sources connected. Run 'msgme init', then set SLACK_TOKEN.")
		return
	}
	for _, s := range srcs {
		secs := s.Sections()
		titles := make([]string, len(secs))
		for i, sec := range secs {
			titles[i] = sec.Title
		}
		fmt.Printf("  ok %s: %v\n", s.Name(), titles)
	}
}

func runTUI() {
	cfg, err := config.Load()
	if err != nil {
		fail(err)
	}
	srcs, warns := build(context.Background(), cfg)
	// Always launch: providers that did not connect become setup tabs whose body
	// explains how to connect them, so msgme is useful even with no token set.
	tabs := setupTabs(srcs, warns)

	refresh := time.Duration(cfg.RefreshMinutes) * time.Minute
	m := tui.New(srcs, tabs, refresh)
	p := tea.NewProgram(m, tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		fail(err)
	}
}

func fail(err error) {
	fmt.Fprintf(os.Stderr, "msgme: %v\n", err)
	os.Exit(1)
}
