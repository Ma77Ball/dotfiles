package tui

import "github.com/charmbracelet/bubbles/key"

// keyMap holds todome's keybindings, vim-flavored like gh-dash/msgme.
type keyMap struct {
	Up       key.Binding
	Down     key.Binding
	NextView key.Binding
	PrevView key.Binding
	Add      key.Binding
	Edit     key.Binding
	Notes    key.Binding
	Toggle   key.Binding
	Delete   key.Binding
	PrioUp   key.Binding
	PrioDown key.Binding
	Preview  key.Binding
	Help     key.Binding
	Quit     key.Binding
	Confirm  key.Binding
	Cancel   key.Binding
}

var keys = keyMap{
	Up:       key.NewBinding(key.WithKeys("k", "up"), key.WithHelp("k/↑", "up")),
	Down:     key.NewBinding(key.WithKeys("j", "down"), key.WithHelp("j/↓", "down")),
	NextView: key.NewBinding(key.WithKeys("tab", "l", "right"), key.WithHelp("tab", "next view")),
	PrevView: key.NewBinding(key.WithKeys("shift+tab", "h", "left"), key.WithHelp("shift+tab", "prev view")),
	Add:      key.NewBinding(key.WithKeys("a", "n"), key.WithHelp("a", "add")),
	Edit:     key.NewBinding(key.WithKeys("e", "enter"), key.WithHelp("e", "edit")),
	Notes:    key.NewBinding(key.WithKeys("N"), key.WithHelp("N", "notes")),
	Toggle:   key.NewBinding(key.WithKeys(" ", "x"), key.WithHelp("space", "toggle done")),
	Delete:   key.NewBinding(key.WithKeys("d"), key.WithHelp("d", "delete")),
	PrioUp:   key.NewBinding(key.WithKeys("+", "="), key.WithHelp("+", "raise priority")),
	PrioDown: key.NewBinding(key.WithKeys("-", "_"), key.WithHelp("-", "lower priority")),
	Preview:  key.NewBinding(key.WithKeys("p"), key.WithHelp("p", "toggle preview")),
	Help:     key.NewBinding(key.WithKeys("?"), key.WithHelp("?", "help")),
	Quit:     key.NewBinding(key.WithKeys("q", "ctrl+c"), key.WithHelp("q", "quit")),
	Confirm:  key.NewBinding(key.WithKeys("enter"), key.WithHelp("enter", "save")),
	Cancel:   key.NewBinding(key.WithKeys("ctrl+g", "esc"), key.WithHelp("ctrl+g", "cancel")),
}
