package api

import (
	"encoding/json"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/evanbackup1256-ship-it/-kick-loader/go/internal/config"
)

type Server struct {
	cfg config.Config
}

func New(cfg config.Config) *Server {
	return &Server{cfg: cfg}
}

func (s *Server) Health(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"ok":      true,
		"service": "alleral-go",
		"at":      time.Now().UTC().Format(time.RFC3339),
	})
}

func (s *Server) Site(w http.ResponseWriter, r *http.Request) {
	var site map[string]any
	if err := config.ReadJSON(s.cfg.SiteJSON, &site); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]any{"ok": false, "error": "site_unavailable"})
		return
	}
	site["ok"] = true
	writeJSON(w, http.StatusOK, site)
}

func (s *Server) LiveStatus(w http.ResponseWriter, r *http.Request) {
	var site map[string]any
	if err := config.ReadJSON(s.cfg.SiteJSON, &site); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]any{"ok": false, "error": "site_unavailable"})
		return
	}

	gamesRaw, _ := site["games"].(map[string]any)
	working := 0
	items := make([]map[string]any, 0)
	for gid, meta := range gamesRaw {
		game, ok := meta.(map[string]any)
		if !ok {
			continue
		}
		status := strings.ToLower(asString(game["status"], "working"))
		if status == "working" {
			working++
		}
		items = append(items, map[string]any{
			"id":      gid,
			"name":    firstNonEmpty(asString(game["name"], ""), gid),
			"status":  status,
			"version": game["version"],
			"message": game["message"],
		})
	}

	var release map[string]any
	_ = config.ReadJSON(s.cfg.ReleaseJSON, &release)

	writeJSON(w, http.StatusOK, map[string]any{
		"ok": true,
		"at": time.Now().UTC().Format(time.RFC3339),
		"versions": map[string]any{
			"loader":    site["loaderVersion"],
			"core":      site["coreVersion"],
			"ui":        site["uiLibrary"],
			"uiVersion": site["uiVersion"],
		},
		"release": map[string]any{
			"commit":    firstNonEmpty(asString(release["commit"], ""), asString(site["githubCommit"], "")),
			"branch":    "main",
			"updatedAt": firstNonEmpty(asString(site["updatedAt"], ""), asString(release["updatedAt"], "")),
		},
		"sync": map[string]any{
			"enabled":    true,
			"autoStatus": true,
			"lastSyncAt": site["updatedAt"],
		},
		"games": map[string]any{
			"total":   len(gamesRaw),
			"working": working,
			"items":   items,
		},
		"relay": map[string]any{
			"online":   true,
			"autoSync": true,
			"engine":   "go",
		},
	})
}

func (s *Server) SyncStatus(w http.ResponseWriter, r *http.Request) {
	var release map[string]any
	_ = config.ReadJSON(s.cfg.ReleaseJSON, &release)
	writeJSON(w, http.StatusOK, map[string]any{
		"ok":         true,
		"enabled":    true,
		"autoStatus": true,
		"commit":     release["commit"],
		"updatedAt":  release["updatedAt"],
		"engine":     "go",
	})
}

func (s *Server) HubVisit(w http.ResponseWriter, r *http.Request) {
	io.Copy(io.Discard, r.Body)
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

func normalizeProxyPath(path string) string {
	if path == "" {
		return "/"
	}
	if len(path) > 1 && strings.HasSuffix(path, "/") {
		return strings.TrimSuffix(path, "/")
	}
	return path
}

func pathsEqualIgnoringSlash(a, b string) bool {
	return normalizeProxyPath(a) == normalizeProxyPath(b)
}

func redirectStatus(code int) bool {
	return code == http.StatusMovedPermanently ||
		code == http.StatusFound ||
		code == http.StatusSeeOther ||
		code == http.StatusTemporaryRedirect ||
		code == http.StatusPermanentRedirect
}

func locationPath(location string, req *http.Request) string {
	if location == "" {
		return ""
	}
	if strings.HasPrefix(location, "/") {
		return location
	}
	parsed, err := url.Parse(location)
	if err != nil {
		return ""
	}
	if parsed.Host != "" && !strings.EqualFold(parsed.Host, req.Host) {
		return ""
	}
	return parsed.Path
}

func alternateSlashPath(path string) string {
	if path == "" || path == "/" {
		return path
	}
	if strings.HasSuffix(path, "/") {
		return strings.TrimSuffix(path, "/")
	}
	return path + "/"
}

var hopByHopHeaders = map[string]struct{}{
	"connection":          {},
	"keep-alive":          {},
	"proxy-authenticate":  {},
	"proxy-authorization": {},
	"te":                  {},
	"trailers":            {},
	"transfer-encoding":   {},
	"upgrade":             {},
}

func (s *Server) ApiNotFound(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusNotFound, map[string]any{
		"ok":    false,
		"error": "api_not_found",
		"path":  r.URL.Path,
	})
}

func (s *Server) ProxyPython(upstream string) http.Handler {
	target := strings.TrimRight(upstream, "/")
	targetURL, err := url.Parse(target)
	if err != nil || targetURL.Host == "" {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			writeJSON(w, http.StatusBadGateway, map[string]any{"ok": false, "error": "bad_upstream"})
		})
	}

	client := &http.Client{
		Timeout: 120 * time.Second,
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			return http.ErrUseLastResponse
		},
	}

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if strings.EqualFold(targetURL.Host, r.Host) {
			writeJSON(w, http.StatusBadGateway, map[string]any{"ok": false, "error": "upstream_loop"})
			return
		}

		path := normalizeProxyPath(r.URL.Path)

		doProxy := func(proxyPath string) (*http.Response, error) {
			proxyPath = normalizeProxyPath(proxyPath)
			reqURL := target + proxyPath
			if r.URL.RawQuery != "" {
				reqURL += "?" + r.URL.RawQuery
			}
			req, err := http.NewRequestWithContext(r.Context(), r.Method, reqURL, r.Body)
			if err != nil {
				return nil, err
			}
			for k, vals := range r.Header {
				if strings.EqualFold(k, "Host") {
					continue
				}
				for _, v := range vals {
					req.Header.Add(k, v)
				}
			}
			req.Host = targetURL.Host
			return client.Do(req)
		}

		res, err := doProxy(path)
		if err != nil {
			writeJSON(w, http.StatusBadGateway, map[string]any{"ok": false, "error": "upstream_unavailable"})
			return
		}

		for attempt := 0; attempt < 2 && redirectStatus(res.StatusCode); attempt++ {
			locPath := locationPath(res.Header.Get("Location"), r)
			if locPath == "" || !pathsEqualIgnoringSlash(locPath, path) {
				break
			}
			res.Body.Close()
			nextPath := normalizeProxyPath(alternateSlashPath(locPath))
			res, err = doProxy(nextPath)
			if err != nil {
				writeJSON(w, http.StatusBadGateway, map[string]any{"ok": false, "error": "upstream_unavailable"})
				return
			}
		}

		defer res.Body.Close()

		for k, vals := range res.Header {
			if _, skip := hopByHopHeaders[strings.ToLower(k)]; skip {
				continue
			}
			if redirectStatus(res.StatusCode) && strings.EqualFold(k, "Location") {
				continue
			}
			for _, v := range vals {
				w.Header().Add(k, v)
			}
		}
		if redirectStatus(res.StatusCode) {
			writeJSON(w, http.StatusBadGateway, map[string]any{"ok": false, "error": "upstream_redirect"})
			return
		}
		w.WriteHeader(res.StatusCode)
		io.Copy(w, res.Body)
	})
}

func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

func asString(v any, fallback string) string {
	if s, ok := v.(string); ok && s != "" {
		return s
	}
	return fallback
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if v != "" {
			return v
		}
	}
	return ""
}
