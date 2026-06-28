// Package sources defines the Item model and Source interface implemented by
// each backend.
package sources

import (
	"context"
	"errors"
	"time"
)

// ErrUnsupported is returned by an action a source does not implement.
var ErrUnsupported = errors.New("action not supported by this source")

// Item is one row in the dashboard.
type Item struct {
	ID      string    // stable, source-scoped id
	Source  string    // source name, e.g. "slack"
	Section string    // section/tab title, e.g. "DMs", "Mentions"
	Title   string    // primary line: sender, channel, or subject
	Snippet string    // one-line preview shown in the list
	Body    string    // full content for the preview pane (markdown ok)
	Time    time.Time // event time; sorted newest first
	Unread  bool      // drives the unread indicator and counts
	URL     string    // deep link opened with the "o" key

	Handle any // source-specific data for actions; opaque to the TUI
}

// Section is a tab the dashboard shows, mapping to one fetch query on one source.
type Section struct {
	Source string // owning source name
	Title  string // tab label, e.g. "DMs"
	Key    string // key the source switches on inside Fetch

	// Setup, when non-empty, marks a placeholder tab for an unconnected provider:
	// the TUI shows this text instead of a list and never calls Fetch.
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
