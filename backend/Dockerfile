FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY telemetry_relay.py .
ENV TELEMETRY_HOST=0.0.0.0
EXPOSE 8080
CMD sh -c "gunicorn -w 2 -b 0.0.0.0:${PORT:-8080} --timeout 120 telemetry_relay:app"
