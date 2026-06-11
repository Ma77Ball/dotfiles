package tui

import (
	"context"
	"strings"
	"testing"
	"time"

	"github.com/Ma77Ball/msgme/internal/sources"
	tea "github.com/charmbracelet/bubbletea"
)

// fakeSource is a deterministic in-memory source for rendering tests.
type fakeSource struct {
	marked  int
	replies []string
}

func (f *fakeSource) Name() string { return "fake" }
func (f *fakeSource) Sections() []sources.Section {
	return []sources.Section{
		{Source: "fake", Title: "DMs", Key: "dms"},
		{Source: "fake", Title: "Mentions", Key: "mentions"},
	}
}
func (f *fakeSource) Fetch(_ context.Context, sec sources.Section) ([]sources.Item, error) {
	if sec.Key != "dms" {
		return nil, nil
	}
	return []sources.Item{
		{ID: "1", Source: "fake", Section: "DMs", Title: "Ada", Snippet: "hi there", Body: "hi there", Time: time.Now(), Unread: true, Handle: "1"},
		{ID: "2", Source: "fake", Section: "DMs", Title: "Linus", Snippet: "ping", Body: "ping", Time: time.Now().Add(-time.Hour), Unread: true, Handle: "2"},
	}, nil
}
func (f *fakeSource) MarkRead(_ context.Context, _ sources.Item) error { f.marked++; return nil }
func (f *fakeSource) Reply(_ context.Context, _ sources.Item, t string) error {
	f.replies = append(f.replies, t)
	return nil
}

func newTestModel(t *testing.T) (Model, *fakeSource) {
	t.Helper()
	fs := &fakeSource{}
	m := New([]sources.Source{fs}, nil, 0)
	// Give it a size so layout/render works.
	updated, _ := m.Update(tea.WindowSizeMsg{Width: 100, Height: 24})
	return updated.(Model), fs
}

func send(m Model, msg tea.Msg) Model {
	updated, _ := m.Update(msg)
	return updated.(Model)
}

func TestRendersFetchedItems(t *testing.T) {
	m, _ := newTestModel(t)
	m = send(m, fetchedMsg{section: 0, items: mustFetch(t, m, 0)})
	out := m.View()
	if !strings.Contains(out, "Ada") || !strings.Contains(out, "hi there") {
		t.Fatalf("view missing rows:\n%s", out)
	}
	// Tab label should show the unread count (2).
	if !strings.Contains(out, "DMs (2)") {
		t.Fatalf("expected unread count in tab, got:\n%s", out)
	}
}

func TestReplyFlowCallsSource(t *testing.T) {
	m, fs := newTestModel(t)
	m = send(m, fetchedMsg{section: 0, items: mustFetch(t, m, 0)})

	m = send(m, tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune("c")}) // enter reply mode
	if m.mode != modeReply {
		t.Fatalf("expected reply mode")
	}
	for _, r := range "hello" {
		m = send(m, tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{r}})
	}
	updated, cmd := m.Update(tea.KeyMsg{Type: tea.KeyEnter})
	m = updated.(Model)
	if cmd == nil {
		t.Fatalf("expected a reply command")
	}
	cmd() // execute the reply command synchronously
	if len(fs.replies) != 1 || fs.replies[0] != "hello" {
		t.Fatalf("reply not delivered: %#v", fs.replies)
	}
}

func TestMarkReadCallsSource(t *testing.T) {
	m, fs := newTestModel(t)
	m = send(m, fetchedMsg{section: 0, items: mustFetch(t, m, 0)})
	updated, cmd := m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune("m")})
	_ = updated
	if cmd == nil {
		t.Fatalf("expected mark-read command")
	}
	cmd()
	if fs.marked != 1 {
		t.Fatalf("expected MarkRead called once, got %d", fs.marked)
	}
}

func TestSetupTabRendersInstructions(t *testing.T) {
	// No connected sources, one placeholder setup tab: the dashboard must still
	// open and show connection instructions instead of crashing or exiting.
	setup := sources.Section{Source: "slack", Title: "Slack", Setup: "Slack is not connected.\nexport SLACK_TOKEN=xoxp-..."}
	m := New(nil, []sources.Section{setup}, 0)
	updated, _ := m.Update(tea.WindowSizeMsg{Width: 100, Height: 24})
	m = updated.(Model)

	out := m.View()
	if !strings.Contains(out, "Connect Slack") {
		t.Fatalf("expected setup heading in view:\n%s", out)
	}
	if !strings.Contains(out, "SLACK_TOKEN") {
		t.Fatalf("expected setup instructions in view:\n%s", out)
	}
	// The tab should carry the not-connected marker.
	if !strings.Contains(out, "○ Slack") {
		t.Fatalf("expected hollow marker on setup tab:\n%s", out)
	}
}

func TestSetupTabNeverFetches(t *testing.T) {
	// Init must not try to Fetch a setup tab (there is no source for it).
	setup := sources.Section{Source: "slack", Title: "Slack", Setup: "help"}
	m := New(nil, []sources.Section{setup}, 0)
	// Refresh on a setup tab is a no-op (would panic on a nil source otherwise).
	_, cmd := m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune("r")})
	if cmd != nil {
		t.Fatalf("expected refresh to be a no-op on a setup tab")
	}
}

func TestAppAndSubNavigation(t *testing.T) {
	fs := &fakeSource{} // app "Fake" with sub-tabs DMs (0) and Mentions (1)
	setup := sources.Section{Source: "gcal", Title: "Calendar", Setup: "x"}
	m := New([]sources.Source{fs}, []sources.Section{setup}, 0)
	u, _ := m.Update(tea.WindowSizeMsg{Width: 100, Height: 24})
	m = u.(Model)

	if len(m.apps) != 2 {
		t.Fatalf("want 2 apps (Fake, Calendar), got %d", len(m.apps))
	}
	if m.active != 0 {
		t.Fatalf("want active section 0 (DMs), got %d", m.active)
	}

	rune := func(r rune) tea.KeyMsg { return tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{r}} }

	// l/h cycle sub-tabs within the active app.
	m = send(m, rune('l'))
	if m.active != 1 {
		t.Fatalf("l should move to Mentions (section 1), got %d", m.active)
	}
	m = send(m, rune('h'))
	if m.active != 0 {
		t.Fatalf("h should move back to DMs (section 0), got %d", m.active)
	}

	// tab cycles to the next app (Calendar, a setup tab).
	m = send(m, tea.KeyMsg{Type: tea.KeyTab})
	if m.activeApp != 1 {
		t.Fatalf("tab should move to app 1, got %d", m.activeApp)
	}
	if !m.isSetup(m.active) {
		t.Fatalf("Calendar app should resolve to a setup section")
	}

	// l on a single-sub (setup) app is a no-op.
	before := m.active
	m = send(m, rune('l'))
	if m.active != before {
		t.Fatalf("l on a single-sub app should be a no-op, moved %d->%d", before, m.active)
	}
}

func mustFetch(t *testing.T, m Model, section int) []sources.Item {
	t.Helper()
	items, err := m.srcs[m.sections[section].Source].Fetch(context.Background(), m.sections[section])
	if err != nil {
		t.Fatal(err)
	}
	return items
}
