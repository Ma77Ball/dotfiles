// Package config loads msgme's YAML config from the XDG config dir
// (~/.config/msgme/config.yml), mirroring how gh-dash is configured.
package config

import (
	"fmt"
	"os"
	"path/filepath"

	"gopkg.in/yaml.v3"
)

// Config is the whole on-disk configuration.
type Config struct {
	// Slack holds the Slack source settings. Nil/disabled if not configured.
	Slack SlackConfig `yaml:"slack"`

	// MSGraph holds the Microsoft Graph source (Outlook + Teams) settings.
	MSGraph MSGraphConfig `yaml:"msgraph"`

	// Google holds the Google Calendar source settings.
	Google GoogleConfig `yaml:"google"`

	// RefreshMinutes auto-refreshes every section on this interval. 0 disables.
	RefreshMinutes int `yaml:"refreshMinutes"`
}

// SlackConfig configures the Slack source.
type SlackConfig struct {
	Enabled bool `yaml:"enabled"`

	// Token is a Slack user OAuth token (xoxp-...). For security, prefer leaving
	// this empty and exporting SLACK_TOKEN in the environment instead; the env
	// var wins when both are set. See README for required scopes.
	Token string `yaml:"token"`

	// Sections lists which Slack tabs to show. Defaults applied if empty.
	Sections []string `yaml:"sections"`
}

// MSGraphConfig configures the Microsoft Graph source (Outlook mail + Teams).
type MSGraphConfig struct {
	Enabled bool `yaml:"enabled"`

	// ClientID is the Azure AD app registration (Application/client) ID.
	// Can also be supplied via the MSGRAPH_CLIENT_ID env var.
	ClientID string `yaml:"clientID"`

	// Tenant defaults to "common" (personal + work/school accounts).
	Tenant string `yaml:"tenant"`

	// Sections lists which tabs to show; defaults to Mail + Teams.
	Sections []string `yaml:"sections"`
}

// GoogleConfig configures the Google Calendar source.
type GoogleConfig struct {
	Enabled bool `yaml:"enabled"`

	// ClientID/ClientSecret come from a Google "Desktop app" OAuth client.
	// Can also be supplied via GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET env vars.
	ClientID     string `yaml:"clientID"`
	ClientSecret string `yaml:"clientSecret"`

	// Sections lists which tabs to show; defaults to Calendar.
	Sections []string `yaml:"sections"`
}

// Default returns a config with sensible defaults applied.
func Default() Config {
	return Config{
		RefreshMinutes: 5,
		Slack: SlackConfig{
			Enabled:  false,
			Sections: []string{"DMs", "Mentions"},
		},
		MSGraph: MSGraphConfig{
			Enabled:  false,
			Tenant:   "common",
			Sections: []string{"Mail", "Teams"},
		},
		Google: GoogleConfig{
			Enabled:  false,
			Sections: []string{"Calendar"},
		},
	}
}

// Path returns the resolved config file path, honoring XDG_CONFIG_HOME.
func Path() string {
	base := os.Getenv("XDG_CONFIG_HOME")
	if base == "" {
		home, _ := os.UserHomeDir()
		base = filepath.Join(home, ".config")
	}
	return filepath.Join(base, "msgme", "config.yml")
}

// Load reads the config file, layering it over Default(). A missing file is not
// an error: defaults are returned so first run works. The SLACK_TOKEN env var
// always overrides the file token.
func Load() (Config, error) {
	cfg := Default()
	path := Path()

	data, err := os.ReadFile(path)
	switch {
	case os.IsNotExist(err):
		// First run: keep defaults.
	case err != nil:
		return cfg, fmt.Errorf("reading %s: %w", path, err)
	default:
		if err := yaml.Unmarshal(data, &cfg); err != nil {
			return cfg, fmt.Errorf("parsing %s: %w", path, err)
		}
	}

	if tok := os.Getenv("SLACK_TOKEN"); tok != "" {
		cfg.Slack.Token = tok
		cfg.Slack.Enabled = true
	}
	if id := os.Getenv("MSGRAPH_CLIENT_ID"); id != "" {
		cfg.MSGraph.ClientID = id
		cfg.MSGraph.Enabled = true
	}
	if id := os.Getenv("GOOGLE_CLIENT_ID"); id != "" {
		cfg.Google.ClientID = id
		cfg.Google.Enabled = true
	}
	if sec := os.Getenv("GOOGLE_CLIENT_SECRET"); sec != "" {
		cfg.Google.ClientSecret = sec
	}

	// Fill section defaults when omitted.
	if len(cfg.Slack.Sections) == 0 {
		cfg.Slack.Sections = Default().Slack.Sections
	}
	if len(cfg.MSGraph.Sections) == 0 {
		cfg.MSGraph.Sections = Default().MSGraph.Sections
	}
	if cfg.MSGraph.Tenant == "" {
		cfg.MSGraph.Tenant = "common"
	}
	if len(cfg.Google.Sections) == 0 {
		cfg.Google.Sections = Default().Google.Sections
	}
	return cfg, nil
}

// WriteDefault writes a commented starter config to Path() if none exists.
// Returns the path written (or the existing path) and whether it created one.
func WriteDefault() (string, bool, error) {
	path := Path()
	if _, err := os.Stat(path); err == nil {
		return path, false, nil
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return path, false, err
	}
	if err := os.WriteFile(path, []byte(starterConfig), 0o600); err != nil {
		return path, false, err
	}
	return path, true, nil
}

const starterConfig = `# msgme config - a terminal dashboard of your messages.
# Docs: see README. Edit and re-run msgme.

# How often (minutes) to auto-refresh sections. 0 disables.
refreshMinutes: 5

slack:
  enabled: true
  # A Slack *user* OAuth token (xoxp-...). Prefer exporting SLACK_TOKEN in your
  # shell instead of committing it here; the env var overrides this value.
  token: ""
  # Which Slack tabs to show.
  sections:
    - DMs
    - Mentions

# Microsoft Graph: Outlook mail + Teams chats from one login.
# After filling clientID, run: msgme login ms
msgraph:
  enabled: false
  # Azure AD app registration (Application/client) ID. Or set MSGRAPH_CLIENT_ID.
  clientID: ""
  # "common" works for personal + work/school accounts.
  tenant: common
  sections:
    - Mail
    - Teams

# Google Calendar (read-only upcoming events).
# After filling clientID/clientSecret, run: msgme login google
google:
  enabled: false
  # Google "Desktop app" OAuth client. Or set GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET.
  clientID: ""
  clientSecret: ""
  sections:
    - Calendar
`
