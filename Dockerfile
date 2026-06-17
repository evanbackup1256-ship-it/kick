FROM golang:1.23-alpine AS go-build
WORKDIR /src
COPY go/go.mod go/go.sum* ./
RUN go mod download 2>/dev/null || true
COPY go/ ./
RUN go mod tidy && CGO_ENABLED=0 go build -o /alleral ./cmd/alleral

FROM node:24-alpine AS site-build
WORKDIR /site
COPY relay/site/package.json relay/site/package-lock.json ./
RUN npm install
COPY cfg/site.json ./cfg/site.json
COPY relay/site ./
COPY cfg/site.json /cfg/site.json
ENV SKIP_BACKEND_SYNC=1
ENV ALLERAL_SITE_CONFIG=/site/cfg/site.json
ENV NEXT_PUBLIC_ALLERAL_API=
RUN npm run build

FROM python:3.12-slim
WORKDIR /app
COPY backend/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt
COPY backend/telemetry_relay.py backend/security.py backend/script_registry.py backend/ban_registry.py backend/site_registry.py backend/roblox_api.py backend/weao_api.py backend/auto_sync.py backend/manage_backend.py backend/loader_builder.py ./
COPY bootstrap.luau loader.luau ./loader_src/
COPY hub/core_base.luau hub/core_ui.luau hub/alleral_ui.luau hub/core_hub_ui.luau ./loader_src/hub/
COPY ui/onyx/source.luau ./loader_src/ui/onyx/
COPY ui/iris/source.luau ./loader_src/ui/iris/
COPY cfg/release.json ./loader_src/cfg/release.json
COPY --from=site-build /site/out ./site
RUN if [ -f /app/site/index.html ]; then mv /app/site/index.html /app/site/app.html; fi
COPY --from=go-build /alleral /usr/local/bin/alleral
COPY cfg/scripts_manifest.json ./scripts_manifest.json
COPY cfg/site.json ./site.json
COPY cfg/release.json ./release.json
COPY cfg/weao.json ./weao.json
COPY docker/start.sh /start.sh
RUN chmod +x /start.sh && mkdir -p /app/data && chmod 777 /app/data
ENV TELEMETRY_HOST=0.0.0.0
ENV SCRIPTS_MANIFEST_PATH=/app/scripts_manifest.json
ENV SITE_CONFIG_PATH=/app/site.json
ENV RELEASE_CONFIG_PATH=/app/release.json
ENV LOADER_MODULES_ROOT=/app/loader_src
ENV BAN_DB_PATH=/app/data/bans.db
ENV ALLERAL_DATA_DIR=/app/data
ENV GITHUB_REPO=evanbackup1256-ship-it/kick
ENV GITHUB_BRANCH=main
ENV GITHUB_SYNC_SECONDS=30
ENV AUTO_SYNC_ENABLED=1
EXPOSE 8080
CMD ["/start.sh"]
