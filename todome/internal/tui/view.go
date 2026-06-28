// Rendering for the todome dashboard: tabs, table, sidebar, footer, overlays.
package tui

import (
	"fmt"
	"strings"
	"time"

	"github.com/Ma77Ball/todome/internal/store"
	"github.com/charmbracelet/lipgloss"
)

// View renders the full dashboard.
func (m Model) View() string {
	if !m.ready {
		return "starting todome..."
	}
	return lipgloss.JoinVertical(lipgloss.Left,
		m.renderTabs(),
		m.renderBody(),
		m.renderFooter(),
	)
}

// --- header / view tab row ---

// renderTabs draws the view tabs with counts and the logo.
func (m Model) renderTabs() string {
	active, done := m.st.Counts()
	cells := make([]string, 0, len(views))
	for i, v := range views {
		label := v.title
		switch {
		case v.all:
			label = fmt.Sprintf("%s (%d)", v.title, active+done)
		case v.done:
			label = fmt.Sprintf("%s (%d)", v.title, done)
		default:
			label = fmt.Sprintf("%s (%d)", v.title, active)
		}
		if i == m.activeView {
			cells = append(cells, styTabActive.Render(label))
		} else {
			cells = append(cells, styTab.Render(label))
		}
	}
	tabsLine := strings.Join(cells, styTabSep.Render("│"))
	logo := m.renderLogo() // two lines tall

	left := lipgloss.PlaceVertical(2, lipgloss.Bottom, tabsLine)
	gap := m.width - lipgloss.Width(tabsLine) - lipgloss.Width(logo)
	if gap < 0 {
		gap = 0
	}
	spacer := lipgloss.NewStyle().Width(gap).Height(2).Render("")
	row := lipgloss.JoinHorizontal(lipgloss.Bottom, left, spacer, logo)
	return styTabsRow.Width(m.width).Render(row)
}

func (m Model) renderLogo() string {
	active, _ := m.st.Counts()
	sub := "all caught up"
	if active == 1 {
		sub = "1 to do"
	} else if active > 1 {
		sub = fmt.Sprintf("%d to do", active)
	}
	logo := lipgloss.JoinVertical(lipgloss.Right,
		styLogo.Render("todome"),
		styLogoSub.Render(sub),
	)
	return lipgloss.NewStyle().Padding(0, 2, 0, 1).Render(logo)
}

// --- body ---

// renderBody draws the main area: help/notes overlay, or table plus sidebar.
func (m Model) renderBody() string {
	bodyH := m.height - 4 // 3-line header + footer
	if bodyH < 3 {
		bodyH = 3
	}
	if m.mode == modeHelp {
		return m.renderHelp(m.width, bodyH)
	}
	if m.mode == modeNotes {
		return m.renderNotesEditor(m.width, bodyH)
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

// renderHelp draws the centered keybinding card.
func (m Model) renderHelp(w, h int) string {
	type binding struct{ key, desc string }
	rows := []binding{
		{"j / k", "move down / up"},
		{"tab / shift+tab", "next / previous view"},
		{"a", "add a task"},
		{"e / enter", "edit the title"},
		{"N", "edit notes (ctrl+s save, ctrl+g cancel)"},
		{"space / x", "toggle done"},
		{"+ / -", "raise / lower priority"},
		{"d", "delete (confirm with d / y)"},
		{"p", "toggle the notes pane"},
		{"?", "toggle this help"},
		{"q / ctrl+c", "quit"},
	}
	keyW := 0
	for _, b := range rows {
		if lipgloss.Width(b.key) > keyW {
			keyW = lipgloss.Width(b.key)
		}
	}
	lines := make([]string, 0, len(rows)+2)
	lines = append(lines, styHelpHead.Render("todome keys"), "")
	for _, b := range rows {
		key := styHelpKey.Render(b.key) + strings.Repeat(" ", keyW-lipgloss.Width(b.key))
		lines = append(lines, key+"   "+styHelpDesc.Render(b.desc))
	}
	lines = append(lines, "", styPlaceholder.Render("press any key to close"))
	card := styHelpBox.Render(lipgloss.JoinVertical(lipgloss.Left, lines...))
	return lipgloss.Place(w, h, lipgloss.Center, lipgloss.Center, card)
}

func (m Model) renderNotesEditor(w, h int) string {
	t, _ := m.current()
	head := styTitle.Render("Notes: " + truncate(t.Title, w-10))
	return lipgloss.JoinVertical(lipgloss.Left, head, "", m.notes.View())
}

// --- table ---

const (
	markW = 3 // priority/done marker column
	ageW  = 8 // relative-time column
	rowH  = 2 // lines per row
)

func (m Model) renderTable(w, h int) string {
	taskW := w - markW - ageW
	if taskW < 6 {
		taskW = 6
	}

	header := styHeaderCell.Render(cell("", markW-2, false)) +
		styHeaderCell.Render(cell("TASK", taskW-2, false)) +
		styHeaderCell.Render(cell("AGE", ageW-2, true))
	header = lipgloss.NewStyle().Width(w).MaxWidth(w).Render(header)

	bodyH := h - 1 // header line
	if bodyH < rowH {
		bodyH = rowH
	}
	body := m.renderRows(w, bodyH, taskW)
	return lipgloss.JoinVertical(lipgloss.Left, header, body)
}

// renderRows draws the visible task rows with scrolling, or a placeholder.
func (m Model) renderRows(w, h, taskW int) string {
	rows := m.rows
	if len(rows) == 0 {
		msg := "✓ nothing here"
		if m.activeView == 0 {
			msg = "✓ all caught up, press a to add a task"
		}
		return lipgloss.Place(w, h, lipgloss.Center, lipgloss.Center, styPlaceholder.Render(msg))
	}

	visible := h / rowH
	if visible < 1 {
		visible = 1
	}
	cur := m.cursor[m.activeView]
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
		lines = append(lines, m.renderRow(rows[i], i == cur, w, taskW)...)
	}
	return lipgloss.NewStyle().Width(w).Height(h).Render(strings.Join(lines, "\n"))
}

// renderRow returns the two display lines for one task.
func (m Model) renderRow(t store.Task, selected bool, w, taskW int) []string {
	mark, markSty := marker(t)
	titleFg := colPrimary
	titleStrike := false
	if t.Done {
		titleFg = colFaint
		titleStrike = true
	}

	when := t.Created
	if t.Done && !t.DoneAt.IsZero() {
		when = t.DoneAt
	}

	line1 := markCell(mark, markW, markSty, selected) +
		styledCell(t.Title, taskW, titleFg, false, selected, false, titleStrike) +
		styledCell(humanTime(when), ageW, colFaint, true, selected, false, false)

	snippet := firstLine(t.Notes)
	line2 := styledCell("", markW, colFaint, false, selected, false, false) +
		styledCell(snippet, w-markW, colFaint, false, selected, false, false)
	return []string{line1, line2}
}

// marker returns the leading glyph and style for a task's state/priority.
func marker(t store.Task) (string, lipgloss.Style) {
	if t.Done {
		return "✓", styDoneMark
	}
	switch t.Priority {
	case store.High:
		return "↑", styPrioHigh
	case store.Medium:
		return "•", styPrioMed
	default:
		return "·", styPrioLow
	}
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

// markCell renders the colored leading marker, preserving its glyph color when selected.
func markCell(glyph string, w int, sty lipgloss.Style, selected bool) string {
	st := lipgloss.NewStyle().Width(w).MaxWidth(w).Padding(0, 1).Inline(true)
	if selected {
		st = st.Background(colSelectedBg)
	}
	return st.Render(sty.Render(glyph))
}

// styledCell renders one table cell, extending the selection background when selected.
func styledCell(text string, w int, fg lipgloss.TerminalColor, right, selected, bold, strike bool) string {
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
	if strike {
		st = st.Strikethrough(true)
	}
	if selected {
		st = st.Background(colSelectedBg)
	}
	return st.Render(truncate(text, inner))
}

// --- sidebar / notes preview ---

// renderSidebar draws the selected task's title, meta, and notes preview.
func (m Model) renderSidebar(w, h int) string {
	t, ok := m.current()
	contentW := w - 5
	if contentW < 8 {
		contentW = 8
	}
	if !ok {
		placeholder := styPlaceholder.Render("select a task to preview")
		return stySidebar.Width(w - 1).Height(h).Render(
			lipgloss.Place(contentW, h, lipgloss.Center, lipgloss.Center, placeholder))
	}

	title := styTitle.Render(truncate(t.Title, contentW))
	meta := stySidebarMeta.Render(truncate(m.previewMeta(t), contentW))
	rule := stySidebarRule.Render(strings.Repeat("─", contentW))
	pager := styPager.Render(fmt.Sprintf("%3.0f%%", m.preview.ScrollPercent()*100))
	content := lipgloss.JoinVertical(lipgloss.Left, title, meta, rule, m.preview.View(), rule, pager)
	return stySidebar.Width(w - 1).Height(h).Render(content)
}

func (m Model) previewMeta(t store.Task) string {
	parts := make([]string, 0, 3)
	if t.Done {
		parts = append(parts, "done")
		if !t.DoneAt.IsZero() {
			parts = append(parts, humanTime(t.DoneAt)+" ago")
		}
	} else {
		parts = append(parts, "priority "+t.Priority.String())
		if a := humanTime(t.Created); a != "" {
			if a == "now" {
				parts = append(parts, "added just now")
			} else {
				parts = append(parts, "added "+a+" ago")
			}
		}
	}
	parts = append(parts, fmt.Sprintf("#%d", t.ID))
	return strings.Join(parts, " · ")
}

// --- footer ---

// renderFooter draws the status/help bar, or the add/edit prompt.
func (m Model) renderFooter() string {
	switch m.mode {
	case modeAdd:
		return styFooterBar.Width(m.width).Render(styFooterOk.Render("add ❯ ") + m.input.View())
	case modeEdit:
		return styFooterBar.Width(m.width).Render(styFooterOk.Render("edit ❯ ") + m.input.View())
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
	case m.mode == modeHelp:
		left = styFooterBar.Render(" press any key to close help")
	case m.mode == modeNotes:
		left = styFooterBar.Render(" type notes · ctrl+s save · ctrl+g cancel")
	default:
		left = styFooterBar.Render(" j/k move · tab view · a add · e edit · N notes · space done · +/- prio · d delete · p preview · q quit")
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

// humanTime formats elapsed time since t as a short relative string.
func humanTime(t time.Time) string {
	if t.IsZero() {
		return ""
	}
	d := time.Since(t)
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

// truncate shortens s to max display columns, adding an ellipsis.
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

// wrap hard-wraps s to width w.
func wrap(s string, w int) string {
	if w < 10 {
		w = 10
	}
	var b strings.Builder
	for _, para := range strings.Split(s, "\n") {
		for lipgloss.Width(para) > w {
			b.WriteString(para[:w])
			b.WriteByte('\n')
			para = para[w:]
		}
		b.WriteString(para)
		b.WriteByte('\n')
	}
	return strings.TrimRight(b.String(), "\n")
}

// firstLine returns s up to the first newline.
func firstLine(s string) string {
	if i := strings.IndexByte(s, '\n'); i >= 0 {
		return s[:i]
	}
	return s
}

func trimSpace(s string) string { return strings.TrimSpace(s) }
