// Package tui implements the todome dashboard: a tabbed task list with a notes
// pane, built on Bubbletea + Lipgloss. Mutations persist immediately.
package tui

import (
	"github.com/Ma77Ball/todome/internal/store"
	"github.com/charmbracelet/bubbles/textarea"
	"github.com/charmbracelet/bubbles/textinput"
	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
)

// mode is the current input/overlay state.
type mode int

const (
	modeNormal mode = iota
	modeAdd
	modeEdit
	modeNotes
	modeConfirmDelete
	modeHelp
)

// view is one top-level tab.
type view struct {
	title string
	done  bool // which tasks to show (ignored when all)
	all   bool
}

var views = []view{
	{title: "Active", done: false},
	{title: "Done", done: true},
	{title: "All", all: true},
}

// Model is the root Bubbletea model.
type Model struct {
	st *store.Store

	activeView int
	cursor     map[int]int // view index -> selected row
	rows       []store.Task

	previewVisible bool
	preview        viewport.Model

	mode  mode
	input textinput.Model
	notes textarea.Model

	status    string
	statusErr bool

	width  int
	height int
	ready  bool
}

// New builds the model around a loaded store.
func New(st *store.Store) Model {
	ti := textinput.New()
	ti.CharLimit = 500

	ta := textarea.New()
	ta.CharLimit = 8000
	ta.ShowLineNumbers = false

	m := Model{
		st:             st,
		cursor:         map[int]int{},
		previewVisible: true,
		input:          ti,
		notes:          ta,
	}
	return m
}

func (m Model) Init() tea.Cmd { return nil }

// --- update ---

// Update routes messages to the handler for the current mode.
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
		m.layout()
		m.ready = true
		m.refreshRows()
		return m, nil

	case tea.KeyMsg:
		switch m.mode {
		case modeAdd, modeEdit:
			return m.updateInput(msg)
		case modeNotes:
			return m.updateNotes(msg)
		case modeConfirmDelete:
			return m.updateConfirmDelete(msg)
		case modeHelp:
			// Any key dismisses the help overlay.
			m.mode = modeNormal
			return m, nil
		default:
			return m.updateNormal(msg)
		}
	}
	return m, nil
}

func (m Model) updateNormal(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch {
	case keyMatches(msg, keys.Quit):
		return m, tea.Quit

	case keyMatches(msg, keys.NextView):
		m.activeView = (m.activeView + 1) % len(views)
		m.refreshRows()
		return m, nil

	case keyMatches(msg, keys.PrevView):
		m.activeView = (m.activeView - 1 + len(views)) % len(views)
		m.refreshRows()
		return m, nil

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

	case keyMatches(msg, keys.Help):
		m.mode = modeHelp
		m.setStatus("", false)
		return m, nil

	case keyMatches(msg, keys.Add):
		m.mode = modeAdd
		m.input.SetValue("")
		m.input.Placeholder = "new task, enter to add, ctrl+g to cancel"
		m.input.Focus()
		m.setStatus("adding task", false)
		return m, textinput.Blink

	case keyMatches(msg, keys.Edit):
		if t, ok := m.current(); ok {
			m.mode = modeEdit
			m.input.SetValue(t.Title)
			m.input.Placeholder = "edit title, enter to save, ctrl+g to cancel"
			m.input.CursorEnd()
			m.input.Focus()
			m.setStatus("editing task", false)
			return m, textinput.Blink
		}
		return m, nil

	case keyMatches(msg, keys.Notes):
		if t, ok := m.current(); ok {
			m.mode = modeNotes
			m.notes.SetValue(t.Notes)
			m.notes.Focus()
			m.setStatus("editing notes, ctrl+s to save, ctrl+g to cancel", false)
			return m, textarea.Blink
		}
		return m, nil

	case keyMatches(msg, keys.Toggle):
		if t, ok := m.current(); ok {
			m.st.Toggle(t.ID)
			m.save()
			m.refreshRows()
			m.setStatus("toggled done", false)
		}
		return m, nil

	case keyMatches(msg, keys.PrioUp):
		m.changePriority(1)
		return m, nil

	case keyMatches(msg, keys.PrioDown):
		m.changePriority(-1)
		return m, nil

	case keyMatches(msg, keys.Delete):
		if _, ok := m.current(); ok {
			m.mode = modeConfirmDelete
			m.setStatus("delete this task? d/y to confirm, ctrl+g to cancel", true)
		}
		return m, nil
	}
	return m, nil
}

// updateInput handles the add/edit title prompt.
func (m Model) updateInput(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch {
	case keyMatches(msg, keys.Cancel):
		was := m.mode
		m.mode = modeNormal
		m.input.Blur()
		if was == modeAdd {
			m.setStatus("add canceled", false)
		} else {
			m.setStatus("edit canceled", false)
		}
		return m, nil
	case keyMatches(msg, keys.Confirm):
		text := trimSpace(m.input.Value())
		was := m.mode
		m.mode = modeNormal
		m.input.Blur()
		if text == "" {
			m.setStatus("empty, nothing saved", false)
			return m, nil
		}
		if was == modeAdd {
			t := m.st.Add(text)
			m.save()
			m.activeView = 0 // jump to Active to show the new task
			m.refreshRows()
			m.selectID(t.ID)
			m.setStatus("added", false)
		} else if t, ok := m.current(); ok {
			if tt := m.st.Get(t.ID); tt != nil {
				tt.Title = text
				m.save()
				m.refreshRows()
				m.selectID(tt.ID)
				m.setStatus("saved", false)
			}
		}
		return m, nil
	}
	var cmd tea.Cmd
	m.input, cmd = m.input.Update(msg)
	return m, cmd
}

// updateNotes handles the notes editor (ctrl+s save, ctrl+g cancel).
func (m Model) updateNotes(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "ctrl+g", "esc":
		m.mode = modeNormal
		m.notes.Blur()
		m.setStatus("notes canceled", false)
		return m, nil
	case "ctrl+s":
		m.mode = modeNormal
		m.notes.Blur()
		if t, ok := m.current(); ok {
			if tt := m.st.Get(t.ID); tt != nil {
				tt.Notes = m.notes.Value()
				m.save()
				m.refreshRows()
				m.selectID(tt.ID)
				m.setStatus("notes saved", false)
			}
		}
		return m, nil
	}
	var cmd tea.Cmd
	m.notes, cmd = m.notes.Update(msg)
	return m, cmd
}

func (m Model) updateConfirmDelete(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "d", "y", "enter":
		if t, ok := m.current(); ok {
			m.st.Delete(t.ID)
			m.save()
			m.refreshRows()
			m.setStatus("deleted", false)
		}
		m.mode = modeNormal
		return m, nil
	default:
		m.mode = modeNormal
		m.setStatus("delete canceled", false)
		return m, nil
	}
}

// --- helpers ---

// refreshRows reloads the current view's rows and clamps the cursor.
func (m *Model) refreshRows() {
	v := views[m.activeView]
	m.rows = m.st.Filtered(v.done, v.all)
	if m.cursor[m.activeView] >= len(m.rows) {
		m.cursor[m.activeView] = max0(len(m.rows) - 1)
	}
	m.syncPreview()
}

func (m *Model) moveCursor(delta int) {
	n := len(m.rows)
	if n == 0 {
		return
	}
	c := m.cursor[m.activeView] + delta
	if c < 0 {
		c = 0
	}
	if c >= n {
		c = n - 1
	}
	m.cursor[m.activeView] = c
	m.syncPreview()
}

func (m Model) current() (store.Task, bool) {
	c := m.cursor[m.activeView]
	if c < 0 || c >= len(m.rows) {
		return store.Task{}, false
	}
	return m.rows[c], true
}

// selectID moves the cursor to the row with the given task ID, if present.
func (m *Model) selectID(id int) {
	for i, t := range m.rows {
		if t.ID == id {
			m.cursor[m.activeView] = i
			m.syncPreview()
			return
		}
	}
}

// changePriority bumps the selected task's priority within bounds.
func (m *Model) changePriority(delta int) {
	t, ok := m.current()
	if !ok {
		return
	}
	tt := m.st.Get(t.ID)
	if tt == nil {
		return
	}
	p := int(tt.Priority) + delta
	if p < int(store.Low) {
		p = int(store.Low)
	}
	if p > int(store.High) {
		p = int(store.High)
	}
	tt.Priority = store.Priority(p)
	m.save()
	m.refreshRows()
	m.selectID(tt.ID)
	m.setStatus("priority: "+tt.Priority.String(), false)
}

func (m *Model) save() {
	if err := m.st.Save(); err != nil {
		m.setStatus("save failed: "+err.Error(), true)
	}
}

func (m *Model) setStatus(s string, isErr bool) {
	m.status = s
	m.statusErr = isErr
}

// syncPreview loads the selected task's notes into the preview pane.
func (m *Model) syncPreview() {
	if !m.ready {
		return
	}
	if t, ok := m.current(); ok {
		body := t.Notes
		if trimSpace(body) == "" {
			body = "(no notes, press N to add)"
		}
		m.preview.SetContent(wrap(body, m.preview.Width))
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
	// Reserve: 3-line header (2-line logo/tabs + thick underline) and 1-line footer.
	bodyH := m.height - 4
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
	contentW := pw - 5
	if contentW < 8 {
		contentW = 8
	}
	vh := bodyH - 5 // title, meta, two rules, pager
	if vh < 1 {
		vh = 1
	}
	m.preview = viewport.New(contentW, vh)
	m.input.Width = m.width - 12
	m.notes.SetWidth(m.width - 4)
	m.notes.SetHeight(bodyH - 2)
	m.syncPreview()
}

// keyMatches reports whether the message matches one of the binding's keys.
func keyMatches(msg tea.KeyMsg, b interface{ Keys() []string }) bool {
	s := msg.String()
	for _, k := range b.Keys() {
		if k == s {
			return true
		}
	}
	return false
}

func max0(n int) int {
	if n < 0 {
		return 0
	}
	return n
}
