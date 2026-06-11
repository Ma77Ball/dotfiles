// Package gcal implements sources.Source for Google Calendar (read-only:
// upcoming events). Calendar events have no "unread" or reply concept, so those
// actions return sources.ErrUnsupported.
//
// Auth is the OAuth2 authorization-code flow with a localhost redirect
// (run `msgme login google`). Set up a free OAuth client at
// https://console.cloud.google.com -> APIs & Services -> Credentials:
//   - Enable the "Google Calendar API".
//   - Create an OAuth client ID of type "Desktop app" (allows loopback ports).
//   - Put the client ID and secret in config under google.clientID/clientSecret.
package gcal

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/Ma77Ball/msgme/internal/auth"
	"github.com/Ma77Ball/msgme/internal/sources"
	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"
)

const calBase = "https://www.googleapis.com/calendar/v3"

// Name is the source/login identifier.
const Name = "google"

// Scopes requested at login.
var Scopes = []string{"https://www.googleapis.com/auth/calendar.readonly"}

// Config builds the OAuth2 config for a Google "Desktop app" client.
func Config(clientID, clientSecret string) *oauth2.Config {
	return &oauth2.Config{
		ClientID:     clientID,
		ClientSecret: clientSecret,
		Scopes:       Scopes,
		Endpoint:     google.Endpoint,
	}
}

// Source is the Google Calendar backend.
type Source struct {
	http     *http.Client
	sections []string
}

// New builds the source from a configured client. Returns an error (so the
// caller can surface "run msgme login google") if no cached token exists.
func New(ctx context.Context, clientID, clientSecret string, sectionTitles []string) (*Source, error) {
	if strings.TrimSpace(clientID) == "" {
		return nil, fmt.Errorf("gcal: no clientID (set google.clientID in config)")
	}
	hc, err := auth.Client(ctx, Name, Config(clientID, clientSecret))
	if err != nil {
		return nil, err
	}
	return &Source{http: hc, sections: sectionTitles}, nil
}

func (s *Source) Name() string { return "gcal" }

// SetupTab returns the placeholder tab the dashboard shows when Google Calendar
// is not connected, explaining how to create an OAuth client and log in.
func SetupTab() sources.Section {
	return sources.Section{Source: "gcal", Title: "Calendar", Setup: setupHelp}
}

const setupHelp = `Google Calendar is not connected.

Create a free OAuth client (read-only upcoming events):

  1. https://console.cloud.google.com → APIs & Services → Credentials.
  2. Enable the "Google Calendar API".
  3. Create an OAuth client ID of type "Desktop app".
  4. Put the client ID and secret in the config under
       google.clientID / google.clientSecret
       (or export GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET), then log in:

       msgme login google

Verify any time with:  msgme doctor`

func (s *Source) Sections() []sources.Section {
	out := make([]sources.Section, 0, len(s.sections))
	for _, title := range s.sections {
		out = append(out, sources.Section{Source: "gcal", Title: title, Key: "events"})
	}
	return out
}

type eventsResp struct {
	Items []struct {
		ID       string `json:"id"`
		Summary  string `json:"summary"`
		HTMLLink string `json:"htmlLink"`
		Location string `json:"location"`
		Status   string `json:"status"`
		Start    struct {
			DateTime string `json:"dateTime"`
			Date     string `json:"date"`
		} `json:"start"`
		End struct {
			DateTime string `json:"dateTime"`
			Date     string `json:"date"`
		} `json:"end"`
	} `json:"items"`
}

func (s *Source) Fetch(ctx context.Context, section sources.Section) ([]sources.Item, error) {
	q := url.Values{}
	q.Set("timeMin", nowRFC3339(ctx))
	q.Set("maxResults", "20")
	q.Set("singleEvents", "true")
	q.Set("orderBy", "startTime")

	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, calBase+"/calendars/primary/events?"+q.Encode(), nil)
	resp, err := s.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("gcal: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 400 {
		return nil, fmt.Errorf("gcal: HTTP %d", resp.StatusCode)
	}
	var er eventsResp
	if err := json.NewDecoder(resp.Body).Decode(&er); err != nil {
		return nil, fmt.Errorf("gcal: decode: %w", err)
	}

	items := make([]sources.Item, 0, len(er.Items))
	for _, e := range er.Items {
		if e.Status == "cancelled" {
			continue
		}
		start := e.Start.DateTime
		allDay := false
		if start == "" {
			start = e.Start.Date
			allDay = true
		}
		when := parseTime(start)
		summary := e.Summary
		if summary == "" {
			summary = "(no title)"
		}
		body := fmt.Sprintf("**%s**\n\n%s", summary, formatWhen(when, allDay))
		if e.Location != "" {
			body += "\nlocation: " + e.Location
		}
		items = append(items, sources.Item{
			ID:      "gcal:event:" + e.ID,
			Source:  "gcal",
			Section: section.Title,
			Title:   summary,
			Snippet: formatWhen(when, allDay),
			Body:    body,
			Time:    when,
			Unread:  false, // events are not "unread"; no dot/count
			URL:     e.HTMLLink,
			Handle:  nil,
		})
	}
	return items, nil
}

// Calendar events cannot be marked read or replied to.
func (s *Source) MarkRead(_ context.Context, _ sources.Item) error { return sources.ErrUnsupported }
func (s *Source) Reply(_ context.Context, _ sources.Item, _ string) error {
	return sources.ErrUnsupported
}

// --- utils ---

func parseTime(s string) time.Time {
	if s == "" {
		return time.Time{}
	}
	if t, err := time.Parse(time.RFC3339, s); err == nil {
		return t
	}
	if t, err := time.Parse("2006-01-02", s); err == nil {
		return t
	}
	return time.Time{}
}

func formatWhen(t time.Time, allDay bool) string {
	if t.IsZero() {
		return ""
	}
	if allDay {
		return t.Format("Mon Jan 2") + " (all day)"
	}
	return t.Local().Format("Mon Jan 2 15:04")
}

// nowRFC3339 returns the current time as an RFC3339 string. It accepts a context
// only to keep a single seam for tests; production uses the wall clock.
func nowRFC3339(_ context.Context) string {
	return time.Now().Format(time.RFC3339)
}
