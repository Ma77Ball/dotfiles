package tui

import (
	"strings"

	"github.com/charmbracelet/glamour"
)

// renderMarkdown renders an item body as styled terminal markdown for the
// sidebar, matching gh-dash's glamour-based preview. It uses a fixed dark style
// (rather than auto-detecting) so it never blocks on a terminal query, and
// falls back to the raw text if rendering fails.
func renderMarkdown(body string, width int) string {
	body = strings.TrimSpace(body)
	if body == "" {
		return ""
	}
	if width < 10 {
		width = 10
	}
	r, err := glamour.NewTermRenderer(
		glamour.WithStandardStyle("dark"),
		glamour.WithWordWrap(width),
	)
	if err != nil {
		return body
	}
	out, err := r.Render(body)
	if err != nil {
		return body
	}
	return strings.TrimRight(out, "\n")
}
