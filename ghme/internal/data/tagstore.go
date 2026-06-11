package data

import (
	"encoding/json"
	"os"
	"path/filepath"
	"sync"

	"charm.land/log/v2"
)

// TagStore persists a free-text tag for each PR/issue, keyed by the item's URL
// (which is unique across repos and across PRs vs. issues). Tags are a purely
// local, personal annotation - they never touch GitHub. Stored as a flat
// JSON object {"<url>": "<tag>", ...} under ~/.local/state/gh-dash/tags.json,
// mirroring the DoneStore/bookmark pattern.
type TagStore struct {
	mu       sync.RWMutex
	tags     map[string]string // item URL -> tag
	filePath string
}

func newTagStore(filename string) *TagStore {
	store := &TagStore{
		tags: make(map[string]string),
	}
	filePath, err := getStateFilePath(filename)
	if err != nil {
		log.Error("Failed to get state file path for tags", "err", err)
	}
	store.filePath = filePath
	if err := store.load(); err != nil {
		log.Error("Failed to load tags", "err", err)
	}
	return store
}

func (s *TagStore) load() error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.filePath == "" {
		return nil
	}

	data, err := os.ReadFile(s.filePath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}

	var tagMap map[string]string
	if err := json.Unmarshal(data, &tagMap); err != nil {
		return err
	}
	for url, tag := range tagMap {
		if tag != "" {
			s.tags[url] = tag
		}
	}
	log.Debug("Loaded tags", "count", len(s.tags))
	return nil
}

func (s *TagStore) save() error {
	s.mu.RLock()
	defer s.mu.RUnlock()

	if s.filePath == "" {
		return nil
	}

	data, err := json.MarshalIndent(s.tags, "", "  ")
	if err != nil {
		return err
	}

	dir := filepath.Dir(s.filePath)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}

	// Atomic write: write to a temp file, then rename.
	tmpFile, err := os.CreateTemp(dir, ".tmp-*")
	if err != nil {
		return err
	}
	tmpPath := tmpFile.Name()
	if _, err := tmpFile.Write(data); err != nil {
		tmpFile.Close()
		os.Remove(tmpPath)
		return err
	}
	if err := tmpFile.Close(); err != nil {
		os.Remove(tmpPath)
		return err
	}
	if err := os.Rename(tmpPath, s.filePath); err != nil {
		os.Remove(tmpPath)
		return err
	}

	log.Debug("Saved tags", "count", len(s.tags))
	return nil
}

// Get returns the tag for an item URL, or "" if none is set.
func (s *TagStore) Get(url string) string {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.tags[url]
}

// Set assigns a tag to an item URL and persists asynchronously. An empty tag
// removes the entry.
func (s *TagStore) Set(url, tag string) {
	if tag == "" {
		s.Remove(url)
		return
	}
	s.mu.Lock()
	s.tags[url] = tag
	s.mu.Unlock()
	go s.save()
}

// Remove deletes the tag for an item URL and persists asynchronously.
func (s *TagStore) Remove(url string) {
	s.mu.Lock()
	delete(s.tags, url)
	s.mu.Unlock()
	go s.save()
}

// Flush forces an immediate synchronous save. Useful for testing.
func (s *TagStore) Flush() error {
	return s.save()
}

// Singleton

var (
	tagStore     *TagStore
	tagStoreOnce sync.Once
)

// GetTagStore returns the singleton tag store.
func GetTagStore() *TagStore {
	tagStoreOnce.Do(func() {
		tagStore = newTagStore("tags.json")
	})
	return tagStore
}
