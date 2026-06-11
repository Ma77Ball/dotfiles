// Package msgraph implements sources.Source for Microsoft Graph, covering both
// Outlook mail and Microsoft Teams chats from a single OAuth login.
//
// Auth is the OAuth2 device-code flow against Azure AD (run `msgme login ms`).
// Register a free app at https://portal.azure.com -> App registrations:
//   - Supported account types: personal + work/school ("common") is fine.
//   - Authentication -> "Allow public client flows" = Yes (enables device code).
//   - API permissions (delegated): User.Read, Mail.Read, Mail.Send, Chat.Read,
//     ChatMessage.Send, offline_access.
// Then put the Application (client) ID in config under msgraph.clientID.
package msgraph

import (
	"bytes"
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
)

const graphBase = "https://graph.microsoft.com/v1.0"

// Name is the source/login identifier used on disk and on the command line.
const Name = "ms"

// Scopes requested at login.
var Scopes = []string{
	"offline_access", "User.Read",
	"Mail.Read", "Mail.Send",
	"Chat.Read", "ChatMessage.Send",
}

// Config builds the OAuth2 config for the given app registration. tenant
// defaults to "common" (personal + work/school accounts).
func Config(clientID, tenant string) *oauth2.Config {
	if tenant == "" {
		tenant = "common"
	}
	base := "https://login.microsoftonline.com/" + tenant + "/oauth2/v2.0"
	return &oauth2.Config{
		ClientID: clientID,
		Scopes:   Scopes,
		Endpoint: oauth2.Endpoint{
			AuthURL:       base + "/authorize",
			TokenURL:      base + "/token",
			DeviceAuthURL: base + "/devicecode",
		},
	}
}

// Source is the Microsoft Graph backend.
type Source struct {
	http     *http.Client
	sections []string
}

type handle struct {
	Kind   string // "mail" or "teams"
	ID     string // message id
	ChatID string // chat id (teams only)
}

// New builds the source from a configured client. Returns an error (so the
// caller can surface "run msgme login ms") if no cached token exists.
func New(ctx context.Context, clientID, tenant string, sectionTitles []string) (*Source, error) {
	if strings.TrimSpace(clientID) == "" {
		return nil, fmt.Errorf("msgraph: no clientID (set msgraph.clientID in config)")
	}
	hc, err := auth.Client(ctx, Name, Config(clientID, tenant))
	if err != nil {
		return nil, err
	}
	return &Source{http: hc, sections: sectionTitles}, nil
}

func (s *Source) Name() string { return "msgraph" }

// SetupTab returns the placeholder tab the dashboard shows when Outlook/Teams
// is not connected, explaining how to register an app and log in.
func SetupTab() sources.Section {
	return sources.Section{Source: "msgraph", Title: "Outlook · Teams", Setup: setupHelp}
}

const setupHelp = `Outlook mail + Teams chats are not connected.

One Microsoft login covers both. Register a free app:

  1. https://portal.azure.com → App registrations → New registration.
       Accounts: personal + work/school ("common") is fine.
  2. Authentication → "Allow public client flows" = Yes (device-code login).
  3. API permissions (delegated): User.Read, Mail.Read, Mail.Send,
       Chat.Read, ChatMessage.Send, offline_access.
  4. Put the Application (client) ID in the config under  msgraph.clientID
       (or export MSGRAPH_CLIENT_ID), then log in:

       msgme login ms

Verify any time with:  msgme doctor`

func (s *Source) Sections() []sources.Section {
	out := make([]sources.Section, 0, len(s.sections))
	for _, title := range s.sections {
		key := "mail"
		if strings.EqualFold(title, "teams") {
			key = "teams"
		}
		out = append(out, sources.Section{Source: "msgraph", Title: title, Key: key})
	}
	return out
}

func (s *Source) Fetch(ctx context.Context, section sources.Section) ([]sources.Item, error) {
	switch section.Key {
	case "mail":
		return s.fetchMail(ctx, section)
	case "teams":
		return s.fetchTeams(ctx, section)
	default:
		return nil, fmt.Errorf("msgraph: unknown section %q", section.Title)
	}
}

// --- Outlook mail ---

type mailResp struct {
	Value []struct {
		ID          string `json:"id"`
		Subject     string `json:"subject"`
		BodyPreview string `json:"bodyPreview"`
		Received    string `json:"receivedDateTime"`
		WebLink     string `json:"webLink"`
		IsRead      bool   `json:"isRead"`
		From        struct {
			EmailAddress struct {
				Name    string `json:"name"`
				Address string `json:"address"`
			} `json:"emailAddress"`
		} `json:"from"`
	} `json:"value"`
}

func (s *Source) fetchMail(ctx context.Context, section sources.Section) ([]sources.Item, error) {
	q := url.Values{}
	q.Set("$filter", "isRead eq false")
	q.Set("$top", "25")
	q.Set("$orderby", "receivedDateTime desc")
	q.Set("$select", "id,subject,from,bodyPreview,receivedDateTime,webLink,isRead")
	var resp mailResp
	if err := s.get(ctx, "/me/mailFolders/inbox/messages?"+q.Encode(), &resp); err != nil {
		return nil, err
	}
	items := make([]sources.Item, 0, len(resp.Value))
	for _, m := range resp.Value {
		who := m.From.EmailAddress.Name
		if who == "" {
			who = m.From.EmailAddress.Address
		}
		items = append(items, sources.Item{
			ID:      "msgraph:mail:" + m.ID,
			Source:  "msgraph",
			Section: section.Title,
			Title:   fmt.Sprintf("%s: %s", who, m.Subject),
			Snippet: oneLine(m.BodyPreview),
			Body:    fmt.Sprintf("**%s**\nfrom %s\n\n%s", m.Subject, who, m.BodyPreview),
			Time:    parseTime(m.Received),
			Unread:  !m.IsRead,
			URL:     m.WebLink,
			Handle:  handle{Kind: "mail", ID: m.ID},
		})
	}
	return items, nil
}

// --- Teams chats ---

type chatsResp struct {
	Value []struct {
		ID        string `json:"id"`
		Topic     string `json:"topic"`
		ChatType  string `json:"chatType"`
		WebURL    string `json:"webUrl"`
		Viewpoint struct {
			LastMessageReadDateTime string `json:"lastMessageReadDateTime"`
		} `json:"viewpoint"`
		LastMessagePreview struct {
			ID        string `json:"id"`
			Created   string `json:"createdDateTime"`
			Body      struct {
				Content string `json:"content"`
			} `json:"body"`
			From struct {
				User struct {
					DisplayName string `json:"displayName"`
				} `json:"user"`
			} `json:"from"`
		} `json:"lastMessagePreview"`
	} `json:"value"`
}

func (s *Source) fetchTeams(ctx context.Context, section sources.Section) ([]sources.Item, error) {
	q := url.Values{}
	q.Set("$expand", "lastMessagePreview")
	q.Set("$top", "50")
	var resp chatsResp
	if err := s.get(ctx, "/me/chats?"+q.Encode(), &resp); err != nil {
		return nil, err
	}
	var items []sources.Item
	for _, c := range resp.Value {
		lm := c.LastMessagePreview
		if lm.ID == "" {
			continue
		}
		created := parseTime(lm.Created)
		read := parseTime(c.Viewpoint.LastMessageReadDateTime)
		// Unread if the last message is newer than the read cursor.
		if !read.IsZero() && !created.After(read) {
			continue
		}
		who := lm.From.User.DisplayName
		if who == "" {
			who = "Teams"
		}
		title := who
		if c.Topic != "" {
			title = fmt.Sprintf("%s in %s", who, c.Topic)
		}
		text := stripHTML(lm.Body.Content)
		items = append(items, sources.Item{
			ID:      "msgraph:teams:" + lm.ID,
			Source:  "msgraph",
			Section: section.Title,
			Title:   title,
			Snippet: oneLine(text),
			Body:    fmt.Sprintf("**%s**\n\n%s", title, text),
			Time:    created,
			Unread:  true,
			URL:     c.WebURL,
			Handle:  handle{Kind: "teams", ID: lm.ID, ChatID: c.ID},
		})
	}
	sortByTimeDesc(items)
	return items, nil
}

// --- actions ---

func (s *Source) MarkRead(ctx context.Context, item sources.Item) error {
	h, ok := item.Handle.(handle)
	if !ok {
		return sources.ErrUnsupported
	}
	switch h.Kind {
	case "mail":
		return s.patch(ctx, "/me/messages/"+h.ID, map[string]any{"isRead": true})
	default:
		// Graph has no simple delegated "mark chat read" endpoint.
		return sources.ErrUnsupported
	}
}

func (s *Source) Reply(ctx context.Context, item sources.Item, text string) error {
	h, ok := item.Handle.(handle)
	if !ok {
		return sources.ErrUnsupported
	}
	switch h.Kind {
	case "mail":
		return s.post(ctx, "/me/messages/"+h.ID+"/reply", map[string]any{"comment": text}, nil)
	case "teams":
		body := map[string]any{"body": map[string]any{"content": text}}
		return s.post(ctx, "/me/chats/"+h.ChatID+"/messages", body, nil)
	default:
		return sources.ErrUnsupported
	}
}

// --- REST helpers ---

func (s *Source) get(ctx context.Context, path string, out any) error {
	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, graphBase+path, nil)
	return s.do(req, out)
}

func (s *Source) patch(ctx context.Context, path string, body any) error {
	req, err := newJSONReq(ctx, http.MethodPatch, graphBase+path, body)
	if err != nil {
		return err
	}
	return s.do(req, nil)
}

func (s *Source) post(ctx context.Context, path string, body, out any) error {
	req, err := newJSONReq(ctx, http.MethodPost, graphBase+path, body)
	if err != nil {
		return err
	}
	return s.do(req, out)
}

func newJSONReq(ctx context.Context, method, url string, body any) (*http.Request, error) {
	buf, err := json.Marshal(body)
	if err != nil {
		return nil, err
	}
	req, err := http.NewRequestWithContext(ctx, method, url, bytes.NewReader(buf))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	return req, nil
}

func (s *Source) do(req *http.Request, out any) error {
	resp, err := s.http.Do(req)
	if err != nil {
		return fmt.Errorf("msgraph: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 400 {
		var e struct {
			Error struct {
				Code    string `json:"code"`
				Message string `json:"message"`
			} `json:"error"`
		}
		_ = json.NewDecoder(resp.Body).Decode(&e)
		if e.Error.Message != "" {
			return fmt.Errorf("msgraph: %s (%s)", e.Error.Message, e.Error.Code)
		}
		return fmt.Errorf("msgraph: HTTP %d", resp.StatusCode)
	}
	if out == nil {
		return nil
	}
	return json.NewDecoder(resp.Body).Decode(out)
}

// --- small utils ---

func parseTime(s string) time.Time {
	if s == "" {
		return time.Time{}
	}
	t, err := time.Parse(time.RFC3339, s)
	if err != nil {
		return time.Time{}
	}
	return t
}

func oneLine(s string) string {
	s = strings.ReplaceAll(s, "\n", " ")
	s = strings.TrimSpace(s)
	if len(s) > 120 {
		s = s[:117] + "..."
	}
	return s
}

// stripHTML removes tags from Teams message HTML for a readable preview. Good
// enough for plain text; not a full sanitizer.
func stripHTML(s string) string {
	var b strings.Builder
	inTag := false
	for _, r := range s {
		switch {
		case r == '<':
			inTag = true
		case r == '>':
			inTag = false
		case !inTag:
			b.WriteRune(r)
		}
	}
	return strings.TrimSpace(b.String())
}

func sortByTimeDesc(items []sources.Item) {
	for i := 1; i < len(items); i++ {
		for j := i; j > 0 && items[j].Time.After(items[j-1].Time); j-- {
			items[j], items[j-1] = items[j-1], items[j]
		}
	}
}
