// Command todome is a terminal todo tracker: a tabbed list of tasks you can add,
// edit, prioritize, and complete, modeled on the structure of ghme/msgme. Tasks
// persist to ~/.local/share/todome/tasks.json. It doubles as a tiny CLI so you
// can capture a task without leaving the shell ("todome add ...").
package main

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"text/tabwriter"

	"github.com/Ma77Ball/todome/internal/store"
	"github.com/Ma77Ball/todome/internal/tui"
	tea "github.com/charmbracelet/bubbletea"
)

const usage = `todome - track what you need to do, in a terminal UI

USAGE
  todome                 Launch the dashboard
  todome add <text...>   Add a task from the shell
  todome list [all|done] Print tasks (active by default)
  todome done <id>       Toggle a task's done state
  todome rm <id>         Delete a task
  todome path            Print the tasks file path
  todome --help          Show this help

KEYS (in the TUI)
  j/k move    tab/shift-tab switch view (Active/Done/All)
  a add       e edit       N notes      space toggle done
  +/- change priority      d delete     p toggle preview     q quit

DATA
  ~/.local/share/todome/tasks.json   (override dir with XDG_DATA_HOME)
`

func main() {
	args := os.Args[1:]
	if len(args) > 0 {
		switch args[0] {
		case "-h", "--help", "help":
			fmt.Print(usage)
			return
		case "add":
			runAdd(args[1:])
			return
		case "list", "ls":
			runList(args[1:])
			return
		case "done", "toggle":
			runToggle(args[1:])
			return
		case "rm", "del", "delete":
			runDelete(args[1:])
			return
		case "path":
			fmt.Println(store.Path())
			return
		default:
			fmt.Fprintf(os.Stderr, "todome: unknown command %q\n\n%s", args[0], usage)
			os.Exit(2)
		}
	}
	runTUI()
}

func runTUI() {
	st, err := store.Load()
	if err != nil {
		fail(err)
	}
	p := tea.NewProgram(tui.New(st), tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		fail(err)
	}
}

func runAdd(args []string) {
	text := strings.TrimSpace(strings.Join(args, " "))
	if text == "" {
		fail(fmt.Errorf("usage: todome add <text...>"))
	}
	st, err := store.Load()
	if err != nil {
		fail(err)
	}
	t := st.Add(text)
	if err := st.Save(); err != nil {
		fail(err)
	}
	fmt.Printf("added #%d: %s\n", t.ID, t.Title)
}

func runList(args []string) {
	st, err := store.Load()
	if err != nil {
		fail(err)
	}
	done, all := false, false
	if len(args) > 0 {
		switch args[0] {
		case "all":
			all = true
		case "done":
			done = true
		case "active":
			// default
		default:
			fail(fmt.Errorf("usage: todome list [all|done|active]"))
		}
	}
	tasks := st.Filtered(done, all)
	if len(tasks) == 0 {
		fmt.Println("no tasks")
		return
	}
	w := tabwriter.NewWriter(os.Stdout, 0, 2, 2, ' ', 0)
	for _, t := range tasks {
		mark := " "
		if t.Done {
			mark = "x"
		}
		fmt.Fprintf(w, "#%d\t[%s]\t%s\t%s\n", t.ID, mark, t.Priority, t.Title)
	}
	w.Flush()
}

func runToggle(args []string) {
	id := mustID(args, "done")
	st, err := store.Load()
	if err != nil {
		fail(err)
	}
	t := st.Toggle(id)
	if t == nil {
		fail(fmt.Errorf("no task #%d", id))
	}
	if err := st.Save(); err != nil {
		fail(err)
	}
	state := "active"
	if t.Done {
		state = "done"
	}
	fmt.Printf("#%d now %s: %s\n", t.ID, state, t.Title)
}

func runDelete(args []string) {
	id := mustID(args, "rm")
	st, err := store.Load()
	if err != nil {
		fail(err)
	}
	if !st.Delete(id) {
		fail(fmt.Errorf("no task #%d", id))
	}
	if err := st.Save(); err != nil {
		fail(err)
	}
	fmt.Printf("deleted #%d\n", id)
}

func mustID(args []string, cmd string) int {
	if len(args) == 0 {
		fail(fmt.Errorf("usage: todome %s <id>", cmd))
	}
	id, err := strconv.Atoi(strings.TrimPrefix(args[0], "#"))
	if err != nil {
		fail(fmt.Errorf("invalid id %q", args[0]))
	}
	return id
}

func fail(err error) {
	fmt.Fprintf(os.Stderr, "todome: %v\n", err)
	os.Exit(1)
}
