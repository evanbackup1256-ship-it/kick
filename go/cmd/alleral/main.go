package main

import (
	"log"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"

	"github.com/evanbackup1256-ship-it/kick/go/internal/api"
	"github.com/evanbackup1256-ship-it/kick/go/internal/config"
)

func main() {
	cfg := config.Load()
	srv := api.New(cfg)
	static := api.StaticSite(cfg.SiteDir)

	r := chi.NewRouter()
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type", "X-Requested-With"},
		AllowCredentials: false,
		MaxAge:           300,
	}))

	r.Get("/health", srv.Health)
	r.Get("/", static)
	r.Get("/index.html", static)

	r.Route("/api", func(r chi.Router) {
		r.Get("/health", srv.Health)
		r.Get("/site", srv.Site)
		r.Get("/live/status", srv.LiveStatus)
		r.Get("/sync/status", srv.SyncStatus)
		r.Post("/hub/visit", srv.HubVisit)

		if cfg.PythonUpstream != "" {
			proxy := srv.ProxyPython(cfg.PythonUpstream)
			r.Handle("/", proxy)
			r.Handle("/*", proxy)
		} else {
			r.NotFound(srv.ApiNotFound)
		}
	})

	if cfg.PythonUpstream != "" {
		proxy := srv.ProxyPython(cfg.PythonUpstream)
		r.Handle("/ingest", proxy)
		r.Handle("/ingest/*", proxy)
		r.Handle("/gate/*", proxy)
		r.Handle("/scripts", proxy)
		r.Handle("/scripts/*", proxy)
		r.Handle("/admin/bans", proxy)
		r.Handle("/admin/bans/*", proxy)
	}

	r.Handle("/*", static)

	log.Printf("Alleral Go relay listening on %s (site=%s python=%q)", cfg.Addr, cfg.SiteDir, cfg.PythonUpstream)
	if err := http.ListenAndServe(cfg.Addr, r); err != nil {
		log.Fatal(err)
	}
}
