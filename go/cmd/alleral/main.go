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
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type", "X-Requested-With", "X-Alleral-Key", "X-Admin-Key"},
		AllowCredentials: false,
		MaxAge:           300,
	}))

	if cfg.PythonUpstream != "" {
		proxy := srv.ProxyPython(cfg.PythonUpstream)
		r.Handle("/health", proxy)
		r.Route("/api", func(r chi.Router) {
			r.Handle("/*", proxy)
		})
		r.Handle("/ingest", proxy)
		r.Handle("/ingest/*", proxy)
		r.Handle("/gate/*", proxy)
		r.Handle("/scripts", proxy)
		r.Handle("/scripts/*", proxy)
	r.Handle("/admin/bans", proxy)
	r.Handle("/admin/bans/*", proxy)
	} else {
		r.Get("/health", srv.Health)
		r.Route("/api", func(r chi.Router) {
			r.Get("/health", srv.Health)
			r.Get("/site", srv.Site)
			r.Get("/live/status", srv.LiveStatus)
			r.Get("/sync/status", srv.SyncStatus)
			r.Post("/hub/visit", srv.HubVisit)
			r.NotFound(srv.ApiNotFound)
		})
	}

	r.Handle("/", static)
	r.Handle("/app.html", static)

	r.Handle("/*", static)

	log.Printf("Alleral Go relay listening on %s (site=%s python=%q)", cfg.Addr, cfg.SiteDir, cfg.PythonUpstream)
	if err := http.ListenAndServe(cfg.Addr, r); err != nil {
		log.Fatal(err)
	}
}
