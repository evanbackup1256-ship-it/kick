package api

import (
	"mime"
	"net/http"
	"os"
	"path/filepath"
	"strings"
)

func StaticSite(root string) http.Handler {
	root = filepath.Clean(root)
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if strings.HasPrefix(r.URL.Path, "/api/") || r.URL.Path == "/api" {
			writeJSON(w, http.StatusNotFound, map[string]any{"ok": false, "error": "api_not_found"})
			return
		}

		rel := strings.TrimPrefix(r.URL.Path, "/")
		rel = strings.TrimSuffix(rel, "/")

		if rel == "" || rel == "index.html" {
			serveSiteFile(w, r, root, "index.html")
			return
		}

		if !strings.Contains(rel, ".") {
			htmlPath := rel + ".html"
			if serveSiteFileIfExists(w, r, root, htmlPath) {
				return
			}
		}

		if serveSiteFileIfExists(w, r, root, rel) {
			return
		}

		nested := filepath.ToSlash(filepath.Join(rel, "index.html"))
		if serveSiteFileIfExists(w, r, root, nested) {
			return
		}

		serveSiteFile(w, r, root, "index.html")
	})
}

func serveSiteFileIfExists(w http.ResponseWriter, r *http.Request, root, rel string) bool {
	full, info, err := openStaticFile(root, rel)
	if err != nil {
		return false
	}
	defer full.Close()
	serveStaticContent(w, r, info, full)
	return true
}

func serveSiteFile(w http.ResponseWriter, r *http.Request, root, rel string) {
	full, info, err := openStaticFile(root, rel)
	if err != nil {
		if os.IsNotExist(err) {
			http.NotFound(w, r)
			return
		}
		http.Error(w, "site_unavailable", http.StatusInternalServerError)
		return
	}
	defer full.Close()
	serveStaticContent(w, r, info, full)
}

func openStaticFile(root, rel string) (*os.File, os.FileInfo, error) {
	clean := filepath.Clean(filepath.Join(root, filepath.FromSlash(rel)))
	if clean != root && !strings.HasPrefix(clean, root+string(os.PathSeparator)) {
		return nil, nil, os.ErrNotExist
	}
	info, err := os.Stat(clean)
	if err != nil {
		return nil, nil, err
	}
	if info.IsDir() {
		return nil, nil, os.ErrNotExist
	}
	file, err := os.Open(clean)
	if err != nil {
		return nil, nil, err
	}
	return file, info, nil
}

func serveStaticContent(w http.ResponseWriter, r *http.Request, info os.FileInfo, file *os.File) {
	if ct := mime.TypeByExtension(filepath.Ext(info.Name())); ct != "" {
		w.Header().Set("Content-Type", ct)
	}
	http.ServeContent(w, r, info.Name(), info.ModTime(), file)
}
