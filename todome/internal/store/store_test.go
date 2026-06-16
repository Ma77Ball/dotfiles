package store

import (
	"path/filepath"
	"testing"
)

// newTemp returns a store backed by a temp file so tests never touch real data.
func newTemp(t *testing.T) *Store {
	t.Helper()
	return &Store{path: filepath.Join(t.TempDir(), "tasks.json"), NextID: 1}
}

func TestAddAssignsIncreasingIDs(t *testing.T) {
	s := newTemp(t)
	a := s.Add("first")
	b := s.Add("second")
	if a.ID != 1 || b.ID != 2 {
		t.Fatalf("ids = %d, %d; want 1, 2", a.ID, b.ID)
	}
	if s.NextID != 3 {
		t.Fatalf("NextID = %d; want 3", s.NextID)
	}
}

func TestToggleStampsDoneAt(t *testing.T) {
	s := newTemp(t)
	a := s.Add("task")
	s.Toggle(a.ID)
	if !a.Done || a.DoneAt.IsZero() {
		t.Fatalf("after toggle: Done=%v DoneAt.zero=%v; want done with timestamp", a.Done, a.DoneAt.IsZero())
	}
	s.Toggle(a.ID)
	if a.Done || !a.DoneAt.IsZero() {
		t.Fatalf("after second toggle: Done=%v DoneAt.zero=%v; want active with cleared timestamp", a.Done, a.DoneAt.IsZero())
	}
}

func TestDelete(t *testing.T) {
	s := newTemp(t)
	a := s.Add("task")
	if !s.Delete(a.ID) {
		t.Fatal("Delete returned false for an existing task")
	}
	if s.Delete(a.ID) {
		t.Fatal("Delete returned true for an already-removed task")
	}
	if len(s.Tasks) != 0 {
		t.Fatalf("len(Tasks) = %d; want 0", len(s.Tasks))
	}
}

func TestFilteredSortsActiveByPriority(t *testing.T) {
	s := newTemp(t)
	lo := s.Add("low")
	lo.Priority = Low
	hi := s.Add("high")
	hi.Priority = High
	active := s.Filtered(false, false)
	if len(active) != 2 || active[0].Title != "high" {
		t.Fatalf("active order = %v; want high first", titles(active))
	}
	done := s.Filtered(true, false)
	if len(done) != 0 {
		t.Fatalf("done = %v; want empty", titles(done))
	}
}

func TestSaveLoadRoundTrip(t *testing.T) {
	// Point Path() at a temp dir so Save/Load exercise the real on-disk path.
	t.Setenv("XDG_DATA_HOME", t.TempDir())
	s := &Store{path: Path(), NextID: 1}
	s.Add("persist me")
	s.Toggle(1)
	if err := s.Save(); err != nil {
		t.Fatalf("Save: %v", err)
	}
	reloaded, err := Load()
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	if len(reloaded.Tasks) != 1 || !reloaded.Tasks[0].Done {
		t.Fatalf("reloaded = %v; want one done task", titles(reloaded.Tasks))
	}
	if reloaded.NextID != 2 {
		t.Fatalf("reloaded NextID = %d; want 2", reloaded.NextID)
	}
}

func titles(ts []Task) []string {
	out := make([]string, len(ts))
	for i, t := range ts {
		out[i] = t.Title
	}
	return out
}
