FROM node:24-alpine AS site-build
WORKDIR /site
COPY site/package.json site/package-lock.json ./
RUN npm install
COPY site ./
ENV SKIP_BACKEND_SYNC=1
RUN npm run build

FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY telemetry_relay.py script_registry.py ban_registry.py site_registry.py roblox_api.py weao_api.py auto_sync.py manage_backend.py ./
COPY --from=site-build /site/out ./site
COPY scripts_manifest.json site.json ./
RUN mkdir -p /app/data && chmod 777 /app/data
ENV TELEMETRY_HOST=0.0.0.0
ENV SCRIPTS_MANIFEST_PATH=/app/scripts_manifest.json
ENV SITE_CONFIG_PATH=/app/site.json
ENV BAN_DB_PATH=/app/data/bans.db
ENV ALLERAL_DATA_DIR=/app/data
ENV GITHUB_REPO=evanbackup1256-ship-it/kick
ENV GITHUB_BRANCH=main
ENV GITHUB_SYNC_SECONDS=30
ENV AUTO_SYNC_ENABLED=1
EXPOSE 8080
CMD sh -c "gunicorn -w 2 -b 0.0.0.0:${PORT:-8080} --timeout 120 telemetry_relay:app"
