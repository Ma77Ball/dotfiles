// Package slack implements sources.Source for Slack using a user OAuth token
// (xoxp-...) from config or the SLACK_TOKEN env var.
package slack

import (
	"context"
	"fmt"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/Ma77Ball/msgme/internal/sources"
	"github.com/slack-go/slack"
)

// Source is the Slack backend.
type Source struct {
	api      *slack.Client
	sections []string

	mu        sync.Mutex
	selfID    string            // cached auth user id
	selfName  string            // cached auth user handle (for mention search)
	teamID    string            // cached workspace/team id (for deep links)
	userNames map[string]string // user id -> display name cache
}

// handle carries per-item action data.
type handle struct {
	Channel  string
	TS       string // message timestamp (id and read marker)
	ThreadTS string // thread root, if threaded
}

// New builds a Slack source from a token and the configured section titles.
func New(token string, sectionTitles []string) (*Source, error) {
	if strings.TrimSpace(token) == "" {
		return nil, fmt.Errorf("slack: no token (set SLACK_TOKEN or slack.token in config)")
	}
	return &Source{
		api:       slack.New(token),
		sections:  sectionTitles,
		userNames: map[string]string{},
	}, nil
}

// Name returns the source identifier.
func (s *Source) Name() string { return "slack" }

// SetupTab returns the placeholder tab shown when Slack is not connected.
func SetupTab() sources.Section {
	return sources.Section{Source: "slack", Title: "Slack", Setup: setupHelp}
}

const setupHelp = `Slack is not connected.

Get a user OAuth token (xoxp-…):

  1. Create an app at https://api.slack.com/apps  ("From scratch").
  2. OAuth & Permissions → User Token Scopes, add:
       im:read   im:history
       channels:history   groups:history   mpim:history
       search:read   chat:write   users:read
  3. Install to Workspace, then copy the User OAuth Token (xoxp-…).
  4. Give it to msgme one of two ways, then restart:

       export SLACK_TOKEN=xoxp-…          (preferred; keeps it off disk)

     or run  msgme init  and set  slack.token  in the config file.

Verify any time with:  msgme doctor`

// Sections returns the configured Slack tabs.
func (s *Source) Sections() []sources.Section {
	out := make([]sources.Section, 0, len(s.sections))
	for _, title := range s.sections {
		out = append(out, sources.Section{Source: "slack", Title: title, Key: strings.ToLower(title)})
	}
	return out
}

// Fetch dispatches on the section key.
func (s *Source) Fetch(ctx context.Context, section sources.Section) ([]sources.Item, error) {
	switch section.Key {
	case "dms":
		return s.fetchDMs(ctx, section)
	case "mentions":
		return s.fetchMentions(ctx, section)
	default:
		return nil, fmt.Errorf("slack: unknown section %q", section.Title)
	}
}

// fetchDMs returns unread direct messages, one item per unread DM conversation.
func (s *Source) fetchDMs(ctx context.Context, section sources.Section) ([]sources.Item, error) {
	// populate team id for permalink fallback; error is non-fatal
	_ = s.ensureSelf(ctx)
	convs, _, err := s.api.GetConversationsForUserContext(ctx, &slack.GetConversationsForUserParameters{
		Types: []string{"im"},
		Limit: 100,
	})
	if err != nil {
		return nil, fmt.Errorf("slack: list DMs: %w", err)
	}

	var items []sources.Item
	for _, c := range convs {
		// read cursor (LastRead) and unread count, if populated
		info, err := s.api.GetConversationInfoContext(ctx, &slack.GetConversationInfoInput{
			ChannelID: c.ID,
		})
		if err != nil || info == nil {
			continue
		}
		hist, err := s.api.GetConversationHistoryContext(ctx, &slack.GetConversationHistoryParameters{
			ChannelID: c.ID,
			Limit:     1,
		})
		if err != nil || len(hist.Messages) == 0 {
			continue
		}
		msg := hist.Messages[0]
		// unread if Slack says so or the latest message is past the cursor
		if info.UnreadCountDisplay == 0 && !tsNewer(msg.Timestamp, info.LastRead) {
			continue
		}
		who := s.userName(ctx, c.User)
		items = append(items, sources.Item{
			ID:      "slack:dm:" + c.ID + ":" + msg.Timestamp,
			Source:  "slack",
			Section: section.Title,
			Title:   who,
			Snippet: oneLine(msg.Text),
			Body:    s.renderBody(ctx, who, msg.Text),
			Time:    tsToTime(msg.Timestamp),
			Unread:  true,
			URL:     s.permalink(ctx, c.ID, msg.Timestamp),
			Handle:  handle{Channel: c.ID, TS: msg.Timestamp},
		})
	}
	sortByTimeDesc(items)
	return items, nil
}

// fetchMentions searches for recent messages that @-mention the auth user.
func (s *Source) fetchMentions(ctx context.Context, section sources.Section) ([]sources.Item, error) {
	if err := s.ensureSelf(ctx); err != nil {
		return nil, err
	}
	res, err := s.api.SearchMessagesContext(ctx, "<@"+s.selfID+">", slack.SearchParameters{
		Sort:          "timestamp",
		SortDirection: "desc",
		Count:         30,
	})
	if err != nil {
		return nil, fmt.Errorf("slack: search mentions: %w", err)
	}
	var items []sources.Item
	for _, m := range res.Matches {
		who := m.Username
		if who == "" {
			who = s.userName(ctx, m.User)
		}
		where := m.Channel.Name
		title := who
		if where != "" {
			title = fmt.Sprintf("%s in #%s", who, where)
		}
		items = append(items, sources.Item{
			ID:      "slack:mention:" + m.Channel.ID + ":" + m.Timestamp,
			Source:  "slack",
			Section: section.Title,
			Title:   title,
			Snippet: oneLine(m.Text),
			Body:    s.renderBody(ctx, title, m.Text),
			Time:    tsToTime(m.Timestamp),
			Unread:  true,
			URL:     m.Permalink,
			Handle:  handle{Channel: m.Channel.ID, TS: m.Timestamp, ThreadTS: m.Timestamp},
		})
	}
	sortByTimeDesc(items)
	return items, nil
}

// MarkRead moves the channel's read cursor to the item's timestamp.
func (s *Source) MarkRead(ctx context.Context, item sources.Item) error {
	h, ok := item.Handle.(handle)
	if !ok {
		return sources.ErrUnsupported
	}
	if err := s.api.MarkConversationContext(ctx, h.Channel, h.TS); err != nil {
		return fmt.Errorf("slack: mark read: %w", err)
	}
	return nil
}

// Reply posts text to the item's channel, threading under it when applicable.
func (s *Source) Reply(ctx context.Context, item sources.Item, text string) error {
	h, ok := item.Handle.(handle)
	if !ok {
		return sources.ErrUnsupported
	}
	opts := []slack.MsgOption{slack.MsgOptionText(text, false)}
	if h.ThreadTS != "" {
		opts = append(opts, slack.MsgOptionTS(h.ThreadTS))
	}
	if _, _, err := s.api.PostMessageContext(ctx, h.Channel, opts...); err != nil {
		return fmt.Errorf("slack: reply: %w", err)
	}
	return nil
}

// --- helpers ---

// ensureSelf caches the auth user's id, handle, and team id.
func (s *Source) ensureSelf(ctx context.Context) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.selfID != "" {
		return nil
	}
	at, err := s.api.AuthTestContext(ctx)
	if err != nil {
		return fmt.Errorf("slack: auth test: %w", err)
	}
	s.selfID = at.UserID
	s.selfName = at.User
	s.teamID = at.TeamID
	return nil
}

// permalink returns a web link to a message, falling back to an app.slack.com
// client URL if the API call fails.
func (s *Source) permalink(ctx context.Context, channel, ts string) string {
	link, err := s.api.GetPermalinkContext(ctx, &slack.PermalinkParameters{Channel: channel, Ts: ts})
	if err == nil && link != "" {
		return link
	}
	s.mu.Lock()
	team := s.teamID
	s.mu.Unlock()
	if team != "" {
		return fmt.Sprintf("https://app.slack.com/client/%s/%s", team, channel)
	}
	return ""
}

// userName resolves a user id to a display name, caching the result.
func (s *Source) userName(ctx context.Context, id string) string {
	if id == "" {
		return "unknown"
	}
	s.mu.Lock()
	if n, ok := s.userNames[id]; ok {
		s.mu.Unlock()
		return n
	}
	s.mu.Unlock()

	u, err := s.api.GetUserInfoContext(ctx, id)
	name := id
	if err == nil && u != nil {
		if u.RealName != "" {
			name = u.RealName
		} else if u.Name != "" {
			name = u.Name
		}
	}
	s.mu.Lock()
	s.userNames[id] = name
	s.mu.Unlock()
	return name
}

// renderBody formats a message for the preview pane.
func (s *Source) renderBody(ctx context.Context, who, text string) string {
	return fmt.Sprintf("**%s**\n\n%s", who, text)
}

// oneLine collapses text to a single trimmed line capped at 120 chars.
func oneLine(s string) string {
	s = strings.ReplaceAll(s, "\n", " ")
	s = strings.TrimSpace(s)
	if len(s) > 120 {
		s = s[:117] + "..."
	}
	return s
}

// tsToTime parses a Slack message ts ("1700000000.000200") into a time.Time.
func tsToTime(ts string) time.Time {
	sec := ts
	if dot := strings.IndexByte(ts, '.'); dot >= 0 {
		sec = ts[:dot]
	}
	n, err := strconv.ParseInt(sec, 10, 64)
	if err != nil {
		return time.Time{}
	}
	return time.Unix(n, 0)
}

// tsNewer reports whether Slack timestamp a is strictly newer than b. Empty b
// (no read cursor) counts as unread.
func tsNewer(a, b string) bool {
	if b == "" {
		return true
	}
	af, err1 := strconv.ParseFloat(a, 64)
	bf, err2 := strconv.ParseFloat(b, 64)
	if err1 != nil || err2 != nil {
		return a > b
	}
	return af > bf
}

// sortByTimeDesc sorts items newest first.
func sortByTimeDesc(items []sources.Item) {
	sort.Slice(items, func(i, j int) bool { return items[i].Time.After(items[j].Time) })
}
