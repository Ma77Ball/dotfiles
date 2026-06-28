package tui

import "github.com/charmbracelet/bubbles/key"

// keyMap holds the dashboard keybindings.
type keyMap struct {
	Up       key.Binding
	Down     key.Binding
	NextApp  key.Binding
	PrevApp  key.Binding
	NextSub  key.Binding
	PrevSub  key.Binding
	Refresh  key.Binding
	Open     key.Binding
	MarkRead key.Binding
	Reply    key.Binding
	Preview  key.Binding
	Help     key.Binding
	Quit     key.Binding
	Confirm  key.Binding
	Cancel   key.Binding
}

var keys = keyMap{
	Up:      key.NewBinding(key.WithKeys("k", "up"), key.WithHelp("k/↑", "up")),
	Down:    key.NewBinding(key.WithKeys("j", "down"), key.WithHelp("j/↓", "down")),
	NextApp: key.NewBinding(key.WithKeys("tab"), key.WithHelp("tab", "next app")),
	PrevApp: key.NewBinding(key.WithKeys("shift+tab"), key.WithHelp("shift+tab", "prev app")),
	NextSub: key.NewBinding(key.WithKeys("l", "right"), key.WithHelp("l", "next tab")),
	PrevSub: key.NewBinding(key.WithKeys("h", "left"), key.WithHelp("h", "prev tab")),
	Refresh:  key.NewBinding(key.WithKeys("r"), key.WithHelp("r", "refresh")),
	Open:     key.NewBinding(key.WithKeys("o"), key.WithHelp("o", "open")),
	MarkRead: key.NewBinding(key.WithKeys("m"), key.WithHelp("m", "mark read")),
	Reply:    key.NewBinding(key.WithKeys("c"), key.WithHelp("c", "reply")),
	Preview:  key.NewBinding(key.WithKeys("p"), key.WithHelp("p", "toggle preview")),
	Help:     key.NewBinding(key.WithKeys("?"), key.WithHelp("?", "help")),
	Quit:     key.NewBinding(key.WithKeys("q", "ctrl+c"), key.WithHelp("q", "quit")),
	Confirm:  key.NewBinding(key.WithKeys("enter"), key.WithHelp("enter", "send")),
	Cancel:   key.NewBinding(key.WithKeys("esc"), key.WithHelp("esc", "cancel")),
}
