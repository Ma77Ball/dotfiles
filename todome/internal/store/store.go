// Package store persists todome's tasks as a single JSON file in the XDG data
// dir (~/.local/share/todome/tasks.json). Unlike ghme/msgme, which read remote
// services, todome owns its data, so the store is the whole backend: load the
// file, mutate the in-memory slice, Save() back atomically.
package store

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"time"
)

// Priority is a task's urgency. Higher sorts first.
type Priority int

const (
	Low Priority = iota
	Medium
	High
)

// String returns a short human label for a priority.
func (p Priority) String() string {
	switch p {
	case High:
		return "high"
	case Medium:
		return "med"
	default:
		return "low"
	}
}

// Task is a single todo item.
type Task struct {
	ID       int       `json:"id"`
	Title    string    `json:"title"`
	Notes    string    `json:"notes,omitempty"`
	Priority Priority  `json:"priority"`
	Done     bool      `json:"done"`
	Created  time.Time `json:"created"`
	DoneAt   time.Time `json:"doneAt,omitempty"`
}

// Store is the on-disk task list plus a monotonic ID counter.
type Store struct {
	Tasks  []Task `json:"tasks"`
	NextID int    `json:"nextID"`

	path string // not serialized
}

// Path returns the resolved tasks.json path, honoring XDG_DATA_HOME. Task data
// is application *state*, so it lives under ~/.local/share, not ~/.config like
// msgme/gh-dash, which hold user-edited configuration.
func Path() string {
	base := os.Getenv("XDG_DATA_HOME")
	if base == "" {
		home, _ := os.UserHomeDir()
		base = filepath.Join(home, ".local", "share")
	}
	return filepath.Join(base, "todome", "tasks.json")
}

// Load reads the task file. A missing file is not an error: an empty store is
// returned so the first run works.
func Load() (*Store, error) {
	path := Path()
	s := &Store{path: path, NextID: 1}

	data, err := os.ReadFile(path)
	switch {
	case os.IsNotExist(err):
		return s, nil
	case err != nil:
		return s, fmt.Errorf("reading %s: %w", path, err)
	}
	if err := json.Unmarshal(data, s); err != nil {
		return s, fmt.Errorf("parsing %s: %w", path, err)
	}
	s.path = path
	if s.NextID < 1 {
		s.NextID = s.maxID() + 1
	}
	return s, nil
}

// Save writes the store back atomically (temp file + rename) so a crash mid-write
// never corrupts the task list.
func (s *Store) Save() error {
	dir := filepath.Dir(s.path)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	data, err := json.MarshalIndent(s, "", "  ")
	if err != nil {
		return err
	}
	tmp, err := os.CreateTemp(dir, ".tasks-*.json")
	if err != nil {
		return err
	}
	tmpName := tmp.Name()
	if _, err := tmp.Write(data); err != nil {
		tmp.Close()
		os.Remove(tmpName)
		return err
	}
	if err := tmp.Close(); err != nil {
		os.Remove(tmpName)
		return err
	}
	return os.Rename(tmpName, s.path)
}

// Add appends a new task with the given title and returns it.
func (s *Store) Add(title string) *Task {
	t := Task{
		ID:       s.NextID,
		Title:    title,
		Priority: Medium,
		Created:  time.Now(),
	}
	s.NextID++
	s.Tasks = append(s.Tasks, t)
	return &s.Tasks[len(s.Tasks)-1]
}

// Get returns a pointer to the task with the given ID, or nil.
func (s *Store) Get(id int) *Task {
	for i := range s.Tasks {
		if s.Tasks[i].ID == id {
			return &s.Tasks[i]
		}
	}
	return nil
}

// Delete removes the task with the given ID. Reports whether one was removed.
func (s *Store) Delete(id int) bool {
	for i := range s.Tasks {
		if s.Tasks[i].ID == id {
			s.Tasks = append(s.Tasks[:i], s.Tasks[i+1:]...)
			return true
		}
	}
	return false
}

// Toggle flips a task's done state, stamping/clearing DoneAt. Returns the task.
func (s *Store) Toggle(id int) *Task {
	t := s.Get(id)
	if t == nil {
		return nil
	}
	t.Done = !t.Done
	if t.Done {
		t.DoneAt = time.Now()
	} else {
		t.DoneAt = time.Time{}
	}
	return t
}

// Filtered returns the tasks matching a view, sorted for display: active tasks
// by priority (high first) then oldest-first; done tasks most-recently-done
// first.
func (s *Store) Filtered(done bool, all bool) []Task {
	var out []Task
	for _, t := range s.Tasks {
		if all || t.Done == done {
			out = append(out, t)
		}
	}
	sort.SliceStable(out, func(i, j int) bool {
		a, b := out[i], out[j]
		if a.Done != b.Done {
			return !a.Done // active before done in the "all" view
		}
		if a.Done {
			return a.DoneAt.After(b.DoneAt)
		}
		if a.Priority != b.Priority {
			return a.Priority > b.Priority
		}
		return a.Created.Before(b.Created)
	})
	return out
}

// Counts returns the number of active and done tasks.
func (s *Store) Counts() (active, done int) {
	for _, t := range s.Tasks {
		if t.Done {
			done++
		} else {
			active++
		}
	}
	return
}

func (s *Store) maxID() int {
	m := 0
	for _, t := range s.Tasks {
		if t.ID > m {
			m = t.ID
		}
	}
	return m
}
