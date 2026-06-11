FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY telemetry_relay.py script_registry.py ban_registry.py site_registry.py ./
COPY site ./site
COPY scripts_manifest.json site.json ./
RUN mkdir -p /app/data
ENV TELEMETRY_HOST=0.0.0.0
ENV SCRIPTS_MANIFEST_PATH=/app/scripts_manifest.json
ENV SITE_CONFIG_PATH=/app/site.json
ENV BAN_DB_PATH=/app/data/bans.db
EXPOSE 8080
CMD sh -c "gunicorn -w 2 -b 0.0.0.0:${PORT:-8080} --timeout 120 telemetry_relay:app"
