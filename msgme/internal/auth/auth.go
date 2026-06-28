// Package auth handles OAuth2 token persistence and the device-code and
// loopback-localhost login flows.
package auth

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"golang.org/x/oauth2"
)

// tokenDir returns the per-source token cache directory.
func tokenDir() string {
	base := os.Getenv("XDG_CONFIG_HOME")
	if base == "" {
		home, _ := os.UserHomeDir()
		base = filepath.Join(home, ".config")
	}
	return filepath.Join(base, "msgme", "tokens")
}

// tokenPath returns the cache file path for a source.
func tokenPath(source string) string {
	return filepath.Join(tokenDir(), source+".json")
}

// LoadToken reads a cached token for a source, returning (nil, nil) when none exists.
func LoadToken(source string) (*oauth2.Token, error) {
	data, err := os.ReadFile(tokenPath(source))
	if os.IsNotExist(err) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	var tok oauth2.Token
	if err := json.Unmarshal(data, &tok); err != nil {
		return nil, fmt.Errorf("auth: corrupt token cache for %s: %w", source, err)
	}
	return &tok, nil
}

// SaveToken persists a token with owner-only permissions.
func SaveToken(source string, tok *oauth2.Token) error {
	if err := os.MkdirAll(tokenDir(), 0o700); err != nil {
		return err
	}
	data, err := json.MarshalIndent(tok, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(tokenPath(source), data, 0o600)
}

// cachingSource wraps a TokenSource and persists the token on refresh.
type cachingSource struct {
	source string
	last   *oauth2.Token
	inner  oauth2.TokenSource
}

func (c *cachingSource) Token() (*oauth2.Token, error) {
	tok, err := c.inner.Token()
	if err != nil {
		return nil, err
	}
	if c.last == nil || tok.AccessToken != c.last.AccessToken {
		_ = SaveToken(c.source, tok)
		c.last = tok
	}
	return tok, nil
}

// Client returns an *http.Client using a source's cached token, auto-refreshing
// and re-persisting it. Errors if no token is cached.
func Client(ctx context.Context, source string, cfg *oauth2.Config) (*http.Client, error) {
	tok, err := LoadToken(source)
	if err != nil {
		return nil, err
	}
	if tok == nil {
		return nil, fmt.Errorf("%s: not logged in (run: msgme login %s)", source, source)
	}
	cs := &cachingSource{source: source, last: tok, inner: cfg.TokenSource(ctx, tok)}
	return oauth2.NewClient(ctx, cs), nil
}

// DeviceLogin runs the OAuth2 device-authorization flow and caches the token.
// cfg must have Endpoint.DeviceAuthURL set.
func DeviceLogin(ctx context.Context, source string, cfg *oauth2.Config) error {
	da, err := cfg.DeviceAuth(ctx)
	if err != nil {
		return fmt.Errorf("device auth: %w", err)
	}
	fmt.Printf("\nTo sign in, open:\n  %s\nand enter code: %s\n\n", da.VerificationURI, da.UserCode)
	if da.VerificationURIComplete != "" {
		fmt.Printf("(or open this direct link: %s)\n\n", da.VerificationURIComplete)
	}
	fmt.Println("Waiting for you to finish in the browser...")
	tok, err := cfg.DeviceAccessToken(ctx, da)
	if err != nil {
		return fmt.Errorf("device token: %w", err)
	}
	if err := SaveToken(source, tok); err != nil {
		return err
	}
	fmt.Printf("logged in: %s\n", source)
	return nil
}

// LoopbackLogin runs the OAuth2 authorization-code flow via a one-shot localhost
// server and caches the token. cfg.RedirectURL is set to the loopback address.
func LoopbackLogin(ctx context.Context, source string, cfg *oauth2.Config, openBrowser func(string)) error {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return fmt.Errorf("loopback listen: %w", err)
	}
	defer ln.Close()
	addr := ln.Addr().(*net.TCPAddr)
	cfg.RedirectURL = fmt.Sprintf("http://127.0.0.1:%d/callback", addr.Port)

	state := fmt.Sprintf("msgme-%d", time.Now().UnixNano())
	authURL := cfg.AuthCodeURL(state, oauth2.AccessTypeOffline, oauth2.ApprovalForce)

	type result struct {
		code string
		err  error
	}
	resCh := make(chan result, 1)
	srv := &http.Server{}
	mux := http.NewServeMux()
	mux.HandleFunc("/callback", func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query()
		if e := q.Get("error"); e != "" {
			fmt.Fprintf(w, "login failed: %s. You can close this tab.", e)
			resCh <- result{err: fmt.Errorf("oauth: %s", e)}
			return
		}
		if q.Get("state") != state {
			fmt.Fprint(w, "state mismatch. You can close this tab.")
			resCh <- result{err: fmt.Errorf("oauth: state mismatch")}
			return
		}
		fmt.Fprint(w, "msgme: logged in. You can close this tab and return to the terminal.")
		resCh <- result{code: q.Get("code")}
	})
	srv.Handler = mux
	go func() { _ = srv.Serve(ln) }()
	defer srv.Shutdown(context.Background())

	fmt.Printf("\nOpening your browser to sign in. If it does not open, visit:\n  %s\n\n", authURL)
	if openBrowser != nil {
		openBrowser(authURL)
	}
	fmt.Println("Waiting for you to finish in the browser...")

	select {
	case <-ctx.Done():
		return ctx.Err()
	case res := <-resCh:
		if res.err != nil {
			return res.err
		}
		tok, err := cfg.Exchange(ctx, res.code)
		if err != nil {
			return fmt.Errorf("token exchange: %w", err)
		}
		if err := SaveToken(source, tok); err != nil {
			return err
		}
		fmt.Printf("logged in: %s\n", source)
		return nil
	}
}
