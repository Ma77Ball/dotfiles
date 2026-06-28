package tui

import (
	"fmt"
	"strings"
	"time"

	"github.com/Ma77Ball/msgme/internal/sources"
	"github.com/charmbracelet/lipgloss"
)

// View renders the full dashboard.
func (m Model) View() string {
	if !m.ready {
		return m.spinner.View() + " starting msgme..."
	}
	return lipgloss.JoinVertical(lipgloss.Left,
		m.renderTabs(),
		m.renderSubTabs(),
		m.renderBody(),
		m.renderFooter(),
	)
}

// --- header / app tab row ---

// renderTabs renders the top-level app tab row with the logo.
func (m Model) renderTabs() string {
	cells := make([]string, 0, len(m.apps))
	for i, app := range m.apps {
		connected := !(len(app.secs) == 1 && m.isSetup(app.secs[0]))
		var label string
		switch {
		case !connected:
			label = "○ " + app.title
		case m.appLoading(i):
			label = app.title + " " + m.spinner.View()
		default:
			if n := m.appUnread(i); n > 0 {
				label = fmt.Sprintf("%s (%d)", app.title, n)
			} else {
				label = app.title
			}
		}
		switch {
		case i == m.activeApp:
			cells = append(cells, styTabActive.Render(label))
		case !connected:
			cells = append(cells, styTabSetup.Render(label))
		default:
			cells = append(cells, styTab.Render(label))
		}
	}
	tabsLine := strings.Join(cells, styTabSep.Render("│"))
	logo := m.renderLogo() // two lines tall

	// tabs on the bottom line of a two-line header, logo to the right
	left := lipgloss.PlaceVertical(2, lipgloss.Bottom, tabsLine)
	gap := m.width - lipgloss.Width(tabsLine) - lipgloss.Width(logo)
	if gap < 0 {
		gap = 0
	}
	spacer := lipgloss.NewStyle().Width(gap).Height(2).Render("")
	row := lipgloss.JoinHorizontal(lipgloss.Bottom, left, spacer, logo)
	return styTabsRow.Width(m.width).Render(row)
}

// renderLogo renders the two-line logo with an unread summary.
func (m Model) renderLogo() string {
	sub := "your messages"
	if n := m.totalUnread(); n > 0 {
		sub = fmt.Sprintf("%d unread", n)
	}
	logo := lipgloss.JoinVertical(lipgloss.Right,
		styLogo.Render("msgme"),
		styLogoSub.Render(sub),
	)
	return lipgloss.NewStyle().Padding(0, 2, 0, 1).Render(logo)
}

// renderSubTabs renders the active app's sub-tab bar; blank for unconnected apps.
func (m Model) renderSubTabs() string {
	if len(m.apps) == 0 {
		return ""
	}
	app := m.apps[m.activeApp]
	if len(app.secs) == 1 && m.isSetup(app.secs[0]) {
		return lipgloss.NewStyle().Width(m.width).Render("")
	}
	cells := make([]string, 0, len(app.secs))
	for j, si := range app.secs {
		label := m.sections[si].Title
		if m.loading[si] {
			label += " " + m.spinner.View()
		} else if n := m.unreadCount(si); n > 0 {
			label = fmt.Sprintf("%s (%d)", label, n)
		}
		if j == app.sub {
			cells = append(cells, stySubActive.Render(label))
		} else {
			cells = append(cells, stySub.Render(label))
		}
	}
	row := "  " + strings.Join(cells, "   ")
	return lipgloss.NewStyle().Width(m.width).Render(row)
}

// --- body ---

// renderBody renders the list (and preview) or a setup card.
func (m Model) renderBody() string {
	bodyH := m.height - 5 // header + sub-tab bar + footer
	if bodyH < 3 {
		bodyH = 3
	}
	if m.isSetup(m.active) {
		return m.renderSetup(m.width, bodyH)
	}
	previewW := 0
	if m.previewVisible {
		previewW = m.width * 45 / 100
		if previewW < 30 {
			previewW = 30
		}
	}
	listW := m.width - previewW
	list := m.renderTable(listW, bodyH)
	if !m.previewVisible {
		return list
	}
	return lipgloss.JoinHorizontal(lipgloss.Top, list, m.renderSidebar(previewW, bodyH))
}

// renderSetup renders the centered connection-instructions card.
func (m Model) renderSetup(w, h int) string {
	sec := m.sections[m.active]
	card := lipgloss.JoinVertical(lipgloss.Left,
		stySetupHead.Render("Connect "+sec.Title),
		"",
		stySetupBody.Render(sec.Setup),
	)
	return lipgloss.Place(w, h, lipgloss.Center, lipgloss.Center, stySetupBox.Render(card))
}

// --- table ---
//
// Rows are two lines tall: line 1 is the sender with a right-aligned relative
// time, line 2 is the snippet. The selection background spans both lines.

const (
	dotW  = 3 // unread-dot column
	timeW = 8 // relative-time column
	rowH  = 2 // lines per row
)

// renderTable renders the message list header and rows.
func (m Model) renderTable(w, h int) string {
	fromW := w - dotW - timeW
	if fromW < 6 {
		fromW = 6
	}

	header := styHeaderCell.Render(cell("", dotW-2, false)) +
		styHeaderCell.Render(cell("FROM", fromW-2, false)) +
		styHeaderCell.Render(cell("TIME", timeW-2, true))
	header = lipgloss.NewStyle().Width(w).MaxWidth(w).Render(header)

	bodyH := h - 1 // minus header line
	if bodyH < rowH {
		bodyH = rowH
	}
	body := m.renderRows(w, bodyH, fromW)
	return lipgloss.JoinVertical(lipgloss.Left, header, body)
}

// renderRows renders the visible rows, or a loading/error/empty placeholder.
func (m Model) renderRows(w, h, fromW int) string {
	rows := m.items[m.active]

	if m.loading[m.active] && len(rows) == 0 {
		msg := m.spinner.View() + " loading " + m.sections[m.active].Title + "..."
		return lipgloss.Place(w, h, lipgloss.Center, lipgloss.Center, styPlaceholder.Render(msg))
	}
	if err := m.errs[m.active]; err != nil {
		txt := styError.Render("error: ") + wrap(err.Error(), w-2)
		return lipgloss.NewStyle().Width(w).Height(h).Padding(0, 1).Render(txt)
	}
	if len(rows) == 0 {
		return lipgloss.Place(w, h, lipgloss.Center, lipgloss.Center, styPlaceholder.Render("✓ all caught up"))
	}

	visible := h / rowH
	if visible < 1 {
		visible = 1
	}
	cur := m.cursor[m.active]
	start := 0
	if cur >= visible {
		start = cur - visible + 1
	}
	end := start + visible
	if end > len(rows) {
		end = len(rows)
	}

	lines := make([]string, 0, (end-start)*rowH)
	for i := start; i < end; i++ {
		lines = append(lines, m.renderRow(rows[i], i == cur, w, fromW)...)
	}
	return lipgloss.NewStyle().Width(w).Height(h).Render(strings.Join(lines, "\n"))
}

// renderRow returns the two display lines for one message.
func (m Model) renderRow(it sources.Item, selected bool, w, fromW int) []string {
	dot := " "
	dotFg := colFaint
	if it.Unread {
		dot, dotFg = "●", colUnread
	}
	fromFg := colSecondary
	if it.Unread {
		fromFg = colPrimary
	}
	line1 := colorCell(dot, dotW, dotFg, false, selected, it.Unread) +
		colorCell(it.Title, fromW, fromFg, false, selected, it.Unread) +
		colorCell(humanTime(it.Time), timeW, colFaint, true, selected, false)
	line2 := colorCell("", dotW, colFaint, false, selected, false) +
		colorCell(it.Snippet, w-dotW, colFaint, false, selected, false)
	return []string{line1, line2}
}

// cell pads/truncates text to width w (excluding the cell's own padding).
func cell(text string, w int, right bool) string {
	if w < 1 {
		w = 1
	}
	st := lipgloss.NewStyle().Width(w).MaxWidth(w).Inline(true)
	if right {
		st = st.Align(lipgloss.Right)
	}
	return st.Render(truncate(text, w))
}

// colorCell renders a table cell with color, padding, and selection background.
func colorCell(text string, w int, fg lipgloss.TerminalColor, right, selected, bold bool) string {
	inner := w - 2
	if inner < 1 {
		inner = 1
	}
	st := lipgloss.NewStyle().Width(w).MaxWidth(w).Padding(0, 1).Inline(true).Foreground(fg)
	if right {
		st = st.Align(lipgloss.Right)
	}
	if bold {
		st = st.Bold(true)
	}
	if selected {
		st = st.Background(colSelectedBg)
	}
	return st.Render(truncate(text, inner))
}

// --- sidebar / preview ---

// renderSidebar renders the preview pane for the selected item.
func (m Model) renderSidebar(w, h int) string {
	it, ok := m.current()
	contentW := w - 5 // border (1) + padding (2+2)
	if contentW < 8 {
		contentW = 8
	}
	if !ok {
		placeholder := styPlaceholder.Render("select a message to preview")
		return stySidebar.Width(w - 1).Height(h).Render(
			lipgloss.Place(contentW, h, lipgloss.Center, lipgloss.Center, placeholder))
	}

	title := styTitle.Render(truncate(it.Title, contentW))
	meta := stySidebarMeta.Render(truncate(m.previewMeta(it), contentW))
	rule := stySidebarRule.Render(strings.Repeat("─", contentW))
	pager := styPager.Render(fmt.Sprintf("%3.0f%%", m.preview.ScrollPercent()*100))
	content := lipgloss.JoinVertical(lipgloss.Left, title, meta, rule, m.preview.View(), rule, pager)
	return stySidebar.Width(w - 1).Height(h).Render(content)
}

// previewMeta builds the "section · time · unread" meta line.
func (m Model) previewMeta(it sources.Item) string {
	parts := make([]string, 0, 3)
	if it.Section != "" {
		parts = append(parts, it.Section)
	}
	if t := humanTime(it.Time); t != "" {
		if t == "now" {
			parts = append(parts, "just now")
		} else {
			parts = append(parts, t+" ago")
		}
	}
	if it.Unread {
		parts = append(parts, "unread")
	}
	return strings.Join(parts, " · ")
}

// --- footer ---

// renderFooter renders the reply input, status line, or key hints.
func (m Model) renderFooter() string {
	if m.mode == modeReply {
		return styFooterBar.Width(m.width).Render(styFooterOk.Render("reply ❯ ") + m.reply.View())
	}

	pill := styHelpPill.Render("? help")

	var left string
	switch {
	case m.status != "":
		st := styFooterOk
		if m.statusErr {
			st = styFooterErr
		}
		left = st.Render(" " + m.status)
	case m.isSetup(m.active):
		left = styFooterBar.Render(" tab switch app · follow the steps, then restart · q quit")
	default:
		left = styFooterBar.Render(" j/k move · h/l tab · tab app · o open · m read · c reply · p preview · r refresh · q quit")
	}

	gap := m.width - lipgloss.Width(left) - lipgloss.Width(pill)
	if gap < 0 {
		gap = 0
		left = truncate(left, m.width-lipgloss.Width(pill))
	}
	spacer := styFooterBar.Render(strings.Repeat(" ", gap))
	return styFooterBar.Width(m.width).Render(lipgloss.JoinHorizontal(lipgloss.Top, left, spacer, pill))
}

// --- small utilities ---

// unreadCount counts unread items in a section.
func (m Model) unreadCount(section int) int {
	n := 0
	for _, it := range m.items[section] {
		if it.Unread {
			n++
		}
	}
	return n
}

// totalUnread sums unread across all sections.
func (m Model) totalUnread() int {
	n := 0
	for s := range m.items {
		n += m.unreadCount(s)
	}
	return n
}

// appUnread sums unread across all of an app's sub-tabs.
func (m Model) appUnread(appIdx int) int {
	n := 0
	for _, si := range m.apps[appIdx].secs {
		n += m.unreadCount(si)
	}
	return n
}

// appLoading reports whether any of an app's sub-tabs is currently loading.
func (m Model) appLoading(appIdx int) bool {
	for _, si := range m.apps[appIdx].secs {
		if m.loading[si] {
			return true
		}
	}
	return false
}

// humanTime formats elapsed time as now/Nm/Nh/Nd.
func humanTime(t time.Time) string {
	if t.IsZero() {
		return ""
	}
	d := timeSince(t)
	switch {
	case d < time.Minute:
		return "now"
	case d < time.Hour:
		return fmt.Sprintf("%dm", int(d.Minutes()))
	case d < 24*time.Hour:
		return fmt.Sprintf("%dh", int(d.Hours()))
	default:
		return fmt.Sprintf("%dd", int(d.Hours()/24))
	}
}

// timeSince is an indirection over time.Since for tests.
func timeSince(t time.Time) time.Duration { return time.Since(t) }

// truncate shortens s to max display columns with an ellipsis.
func truncate(s string, max int) string {
	if max <= 0 {
		return ""
	}
	if max == 1 {
		if lipgloss.Width(s) <= 1 {
			return s
		}
		return "…"
	}
	if lipgloss.Width(s) <= max {
		return s
	}
	r := []rune(s)
	if len(r) > max-1 {
		r = r[:max-1]
	}
	return string(r) + "…"
}

// wrap hard-wraps s at width w.
func wrap(s string, w int) string {
	if w < 10 {
		w = 10
	}
	var b strings.Builder
	for len(s) > w {
		b.WriteString(s[:w])
		b.WriteByte('\n')
		s = s[w:]
	}
	b.WriteString(s)
	return b.String()
}
