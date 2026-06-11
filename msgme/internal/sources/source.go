// Package sources defines the unified model and the Source interface that every
// backend (Slack, Outlook, Google Calendar, Microsoft Teams, ...) implements.
//
// The TUI knows nothing about any individual provider: it renders []Item and
// calls the quick-action methods. Adding a provider means adding a sibling
// package under sources/ that satisfies Source; nothing in the TUI changes.
package sources

import (
	"context"
	"errors"
	"time"
)

// ErrUnsupported is returned by an action a source does not implement (e.g.
// replying to a calendar event). The TUI treats it as "action unavailable here"
// rather than a hard failure.
var ErrUnsupported = errors.New("action not supported by this source")

// Item is one row in the dashboard: a Slack message, an email, a calendar
// event, etc. Sources translate their native payloads into this shape.
type Item struct {
	ID      string    // stable, source-scoped id (used for dedupe/actions)
	Source  string    // source name, e.g. "slack"
	Section string    // logical section/tab title, e.g. "DMs", "Mentions"
	Title   string    // primary line: sender, channel, or subject
	Snippet string    // one-line preview shown in the list
	Body    string    // full content for the preview pane (markdown ok)
	Time    time.Time // when it happened; used for sorting (newest first)
	Unread  bool      // drives the unread indicator and counts
	URL     string    // deep link to open in browser/native app ("o" key)

	// Handle carries source-specific data the source needs to perform actions
	// on this item (channel id, message ts, mail id, ...). Opaque to the TUI.
	Handle any
}

// Section is a logical tab the dashboard shows. Each maps to one fetch query
// against one source.
type Section struct {
	Source string // owning source name
	Title  string // tab label, e.g. "DMs"
	Key    string // stable key the source switches on inside Fetch

	// Setup, when non-empty, marks this as a placeholder tab for a provider that
	// is not connected yet. The TUI shows this text (connection instructions) in
	// place of a list/preview and never calls Fetch for it.
	Setup string
}

// Source is one connected backend. Implementations live in sub-packages.
type Source interface {
	// Name is the stable identifier, e.g. "slack".
	Name() string

	// Sections lists the tabs this source contributes, given its config.
	Sections() []Section

	// Fetch returns the items for one of this source's sections, newest first.
	Fetch(ctx context.Context, section Section) ([]Item, error)

	// MarkRead marks the item read on the backend. Return ErrUnsupported if N/A.
	MarkRead(ctx context.Context, item Item) error

	// Reply posts text as a reply to item. Return ErrUnsupported if N/A.
	Reply(ctx context.Context, item Item, text string) error
}
