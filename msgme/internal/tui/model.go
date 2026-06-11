// Package tui implements the msgme dashboard: a tabbed list of message sections
// with a side preview pane and quick actions, built on Bubbletea + Lipgloss.
//
// The model is source-agnostic: it holds a flat list of sources.Section tabs and
// a map of fetched sources.Item rows, and dispatches actions through the owning
// sources.Source. Slack is the only source today; others slot in unchanged.
package tui

import (
	"context"
	"os"
	"os/exec"
	"strings"
	"time"

	"github.com/Ma77Ball/msgme/internal/sources"
	"github.com/charmbracelet/bubbles/spinner"
	"github.com/charmbracelet/bubbles/textinput"
	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
)

type mode int

const (
	modeNormal mode = iota
	modeReply
)

// appTab is one top-level app (a source, connected or not). Its sub-tabs are the
// app's sections; for an unconnected app secs holds its single setup placeholder.
// Apps are cycled with tab/shift-tab; sub-tabs within an app with l/h.
type appTab struct {
	title string // display title, e.g. "Slack"
	secs  []int  // indices into Model.sections (the sub-tabs)
	sub   int    // active sub-tab (index into secs)
}

// Model is the root Bubbletea model.
type Model struct {
	srcs     map[string]sources.Source
	sections []sources.Section

	apps      []appTab // top-level apps; sub-tabs are sections
	activeApp int

	items   map[int][]sources.Item // section index -> rows
	cursor  map[int]int            // section index -> selected row
	loading map[int]bool
	errs    map[int]error

	active         int // current global section index (= apps[activeApp].secs[sub])
	previewVisible bool
	preview        viewport.Model

	mode      mode
	reply     textinput.Model
	spinner   spinner.Model
	status    string
	statusErr bool

	refresh time.Duration
	width   int
	height  int
	ready   bool
}

// New builds the model from connected sources, placeholder setup tabs for
// providers that are not connected, and an auto-refresh interval (0 disables
// auto-refresh). Connected sections come first, then the setup tabs.
func New(srcs []sources.Source, setupTabs []sources.Section, refresh time.Duration) Model {
	byName := map[string]sources.Source{}
	var secs []sources.Section
	for _, s := range srcs {
		byName[s.Name()] = s
		secs = append(secs, s.Sections()...)
	}
	secs = append(secs, setupTabs...)

	ti := textinput.New()
	ti.Placeholder = "type a reply, enter to send, esc to cancel"
	ti.CharLimit = 4000

	sp := spinner.New()
	sp.Spinner = spinner.Dot
	sp.Style = stySpinner

	m := Model{
		srcs:           byName,
		sections:       secs,
		apps:           buildApps(secs),
		items:          map[int][]sources.Item{},
		cursor:         map[int]int{},
		loading:        map[int]bool{},
		errs:           map[int]error{},
		previewVisible: true,
		reply:          ti,
		spinner:        sp,
		refresh:        refresh,
	}
	m.syncActive()
	return m
}

// buildApps groups sections into top-level apps by source, preserving order.
func buildApps(secs []sources.Section) []appTab {
	var apps []appTab
	idx := map[string]int{}
	for i, s := range secs {
		ai, ok := idx[s.Source]
		if !ok {
			title := appTitle(s.Source)
			if s.Setup != "" {
				title = s.Title // setup tabs already carry a display title
			}
			apps = append(apps, appTab{title: title})
			ai = len(apps) - 1
			idx[s.Source] = ai
		}
		apps[ai].secs = append(apps[ai].secs, i)
	}
	return apps
}

// appTitle is the top-level label for a source.
func appTitle(source string) string {
	switch source {
	case "slack":
		return "Slack"
	case "msgraph":
		return "Outlook · Teams"
	case "gcal":
		return "Calendar"
	case "":
		return "?"
	default:
		return strings.ToUpper(source[:1]) + source[1:]
	}
}

// isSetup reports whether the section at index i is a placeholder tab for an
// unconnected provider (no Fetch, no list, just instructions).
func (m Model) isSetup(i int) bool {
	return i >= 0 && i < len(m.sections) && m.sections[i].Setup != ""
}

// syncActive recomputes the current global section index from the active app and
// its active sub-tab.
func (m *Model) syncActive() {
	if len(m.apps) == 0 {
		m.active = 0
		return
	}
	if m.activeApp < 0 || m.activeApp >= len(m.apps) {
		m.activeApp = 0
	}
	a := &m.apps[m.activeApp]
	if a.sub < 0 || a.sub >= len(a.secs) {
		a.sub = 0
	}
	if len(a.secs) > 0 {
		m.active = a.secs[a.sub]
	}
}

// cycleApp moves to the next/previous app (tab / shift-tab).
func (m *Model) cycleApp(d int) {
	if len(m.apps) == 0 {
		return
	}
	m.activeApp = (m.activeApp + d + len(m.apps)) % len(m.apps)
	m.syncActive()
}

// cycleSub moves to the next/previous sub-tab within the active app (l / h).
func (m *Model) cycleSub(d int) {
	if len(m.apps) == 0 {
		return
	}
	a := &m.apps[m.activeApp]
	n := len(a.secs)
	if n <= 1 {
		return
	}
	a.sub = (a.sub + d + n) % n
	m.syncActive()
}

// --- messages ---

type fetchedMsg struct {
	section int
	items   []sources.Item
	err     error
}

type actionMsg struct {
	verb string
	err  error
}

type tickMsg time.Time

func (m Model) Init() tea.Cmd {
	cmds := make([]tea.Cmd, 0, len(m.sections)+2)
	for i := range m.sections {
		if m.isSetup(i) {
			continue
		}
		m.loading[i] = true
		cmds = append(cmds, m.fetchCmd(i))
	}
	cmds = append(cmds, m.spinner.Tick)
	if m.refresh > 0 {
		cmds = append(cmds, tickCmd(m.refresh))
	}
	return tea.Batch(cmds...)
}

// --- commands ---

func (m Model) fetchCmd(section int) tea.Cmd {
	sec := m.sections[section]
	src := m.srcs[sec.Source]
	return func() tea.Msg {
		ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
		defer cancel()
		items, err := src.Fetch(ctx, sec)
		return fetchedMsg{section: section, items: items, err: err}
	}
}

func (m Model) markReadCmd(it sources.Item) tea.Cmd {
	src := m.srcs[it.Source]
	return func() tea.Msg {
		ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
		defer cancel()
		return actionMsg{verb: "marked read", err: src.MarkRead(ctx, it)}
	}
}

func (m Model) replyCmd(it sources.Item, text string) tea.Cmd {
	src := m.srcs[it.Source]
	return func() tea.Msg {
		ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
		defer cancel()
		return actionMsg{verb: "reply sent", err: src.Reply(ctx, it, text)}
	}
}

func tickCmd(d time.Duration) tea.Cmd {
	return tea.Tick(d, func(t time.Time) tea.Msg { return tickMsg(t) })
}

// --- update ---

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
		m.layout()
		m.ready = true
		return m, nil

	case fetchedMsg:
		m.loading[msg.section] = false
		if msg.err != nil {
			m.errs[msg.section] = msg.err
		} else {
			m.errs[msg.section] = nil
			m.items[msg.section] = msg.items
			if m.cursor[msg.section] >= len(msg.items) {
				m.cursor[msg.section] = 0
			}
		}
		if msg.section == m.active {
			m.syncPreview()
		}
		return m, nil

	case actionMsg:
		if msg.err != nil {
			m.setStatus("error: "+msg.err.Error(), true)
		} else {
			m.setStatus(msg.verb, false)
		}
		// Refresh the active section so the change is reflected.
		m.loading[m.active] = true
		return m, m.fetchCmd(m.active)

	case tickMsg:
		cmds := []tea.Cmd{tickCmd(m.refresh)}
		if !m.isSetup(m.active) {
			m.loading[m.active] = true
			cmds = append(cmds, m.fetchCmd(m.active))
		}
		return m, tea.Batch(cmds...)

	case spinner.TickMsg:
		var cmd tea.Cmd
		m.spinner, cmd = m.spinner.Update(msg)
		return m, cmd

	case tea.KeyMsg:
		if m.mode == modeReply {
			return m.updateReply(msg)
		}
		return m.updateNormal(msg)
	}
	return m, nil
}

func (m Model) updateNormal(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch {
	case keyMatches(msg, keys.Quit):
		return m, tea.Quit

	case keyMatches(msg, keys.NextApp):
		m.cycleApp(1)
		m.syncPreview()
		return m, m.maybeFetch(m.active)

	case keyMatches(msg, keys.PrevApp):
		m.cycleApp(-1)
		m.syncPreview()
		return m, m.maybeFetch(m.active)

	case keyMatches(msg, keys.NextSub):
		m.cycleSub(1)
		m.syncPreview()
		return m, m.maybeFetch(m.active)

	case keyMatches(msg, keys.PrevSub):
		m.cycleSub(-1)
		m.syncPreview()
		return m, m.maybeFetch(m.active)

	case keyMatches(msg, keys.Down):
		m.moveCursor(1)
		return m, nil

	case keyMatches(msg, keys.Up):
		m.moveCursor(-1)
		return m, nil

	case keyMatches(msg, keys.Preview):
		m.previewVisible = !m.previewVisible
		m.layout()
		return m, nil

	case keyMatches(msg, keys.Refresh):
		if m.isSetup(m.active) {
			return m, nil
		}
		m.loading[m.active] = true
		m.setStatus("refreshing...", false)
		return m, m.fetchCmd(m.active)

	case keyMatches(msg, keys.Open):
		if it, ok := m.current(); ok && it.URL != "" {
			openURL(it.URL)
			m.setStatus("opened in browser", false)
		}
		return m, nil

	case keyMatches(msg, keys.MarkRead):
		if it, ok := m.current(); ok {
			m.setStatus("marking read...", false)
			return m, m.markReadCmd(it)
		}
		return m, nil

	case keyMatches(msg, keys.Reply):
		if it, ok := m.current(); ok {
			m.mode = modeReply
			m.reply.SetValue("")
			m.reply.Focus()
			m.setStatus("replying to "+it.Title, false)
			return m, textinput.Blink
		}
		return m, nil
	}
	return m, nil
}

func (m Model) updateReply(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch {
	case keyMatches(msg, keys.Cancel):
		m.mode = modeNormal
		m.reply.Blur()
		m.setStatus("reply canceled", false)
		return m, nil
	case keyMatches(msg, keys.Confirm):
		text := strings.TrimSpace(m.reply.Value())
		m.mode = modeNormal
		m.reply.Blur()
		if text == "" {
			m.setStatus("empty reply, nothing sent", false)
			return m, nil
		}
		if it, ok := m.current(); ok {
			m.setStatus("sending...", false)
			return m, m.replyCmd(it, text)
		}
		return m, nil
	}
	var cmd tea.Cmd
	m.reply, cmd = m.reply.Update(msg)
	return m, cmd
}

// --- helpers ---

func (m *Model) moveCursor(delta int) {
	n := len(m.items[m.active])
	if n == 0 {
		return
	}
	c := m.cursor[m.active] + delta
	if c < 0 {
		c = 0
	}
	if c >= n {
		c = n - 1
	}
	m.cursor[m.active] = c
	m.syncPreview()
}

func (m Model) current() (sources.Item, bool) {
	rows := m.items[m.active]
	c := m.cursor[m.active]
	if c < 0 || c >= len(rows) {
		return sources.Item{}, false
	}
	return rows[c], true
}

// maybeFetch lazily loads a section the first time it is visited.
func (m *Model) maybeFetch(section int) tea.Cmd {
	if m.isSetup(section) {
		return nil
	}
	if _, done := m.items[section]; done || m.loading[section] {
		return nil
	}
	m.loading[section] = true
	return m.fetchCmd(section)
}

func (m *Model) setStatus(s string, isErr bool) {
	m.status = s
	m.statusErr = isErr
}

func (m *Model) syncPreview() {
	if !m.ready {
		return
	}
	if it, ok := m.current(); ok {
		m.preview.SetContent(renderMarkdown(it.Body, m.preview.Width))
		m.preview.GotoTop()
	} else {
		m.preview.SetContent("")
	}
}

// layout recomputes pane sizes from the terminal dimensions.
func (m *Model) layout() {
	if m.width == 0 || m.height == 0 {
		return
	}
	// Reserve: 3-line header (2-line logo/tabs + thick underline), 1-line
	// sub-tab bar, 1-line footer.
	bodyH := m.height - 5
	if bodyH < 3 {
		bodyH = 3
	}
	pw := 0
	if m.previewVisible {
		pw = m.width * 45 / 100
		if pw < 30 {
			pw = 30
		}
	}
	// Sidebar content width = pane - left border (1) - horizontal padding (2+2).
	contentW := pw - 5
	if contentW < 8 {
		contentW = 8
	}
	// Sidebar reserves title, meta, two rules, and a pager line around the body.
	vh := bodyH - 5
	if vh < 1 {
		vh = 1
	}
	m.preview = viewport.New(contentW, vh)
	m.reply.Width = m.width - 12
	m.syncPreview()
}

func keyMatches(msg tea.KeyMsg, b interface{ Keys() []string }) bool {
	s := msg.String()
	for _, k := range b.Keys() {
		if k == s {
			return true
		}
	}
	return false
}

// openURL launches the URL via $BROWSER or xdg-open, fully detached so its
// output never paints over the TUI (same trick ghme uses).
func openURL(url string) {
	bin := os.Getenv("BROWSER")
	if bin == "" {
		bin = "xdg-open"
	}
	cmd := exec.Command(bin, url)
	cmd.Stdout, cmd.Stderr, cmd.Stdin = nil, nil, nil
	_ = cmd.Start()
	go func() { _ = cmd.Wait() }()
}
