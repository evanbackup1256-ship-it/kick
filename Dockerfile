FROM python:3.12-slim
WORKDIR /app
COPY backend/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt
COPY backend/telemetry_relay.py backend/script_registry.py backend/ban_registry.py backend/site_registry.py backend/roblox_api.py backend/auto_sync.py ./
COPY backend/site ./site
COPY cfg/scripts_manifest.json ./scripts_manifest.json
COPY cfg/site.json ./site.json
RUN mkdir -p /app/data
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
