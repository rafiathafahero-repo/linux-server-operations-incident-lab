#!/usr/bin/env bash
# Reconstructed from visible lab script/screenshots, not an exported copy.
SERVICE="ops-lab-http.service"
URL="http://127.0.0.1:8765/health.txt"
EXPECTED="SERVER-OPS-LAB-OK"
TIME="$(date --iso-8601=seconds)"

if ! systemctl is-active --quiet "$SERVICE"; then
    echo "[$TIME] CRITICAL: Service is not active"
    exit 2
fi
if ! BODY=$(curl -fsS --max-time 3 "$URL"); then
    echo "[$TIME] CRITICAL: HTTP health check failed"
    exit 2
fi
if [[ "$BODY" != "$EXPECTED" ]]; then
    echo "[$TIME] CRITICAL: Unexpected HTTP response"
    exit 2
fi

echo "[$TIME] OK: Service and HTTP endpoint healthy"
exit 0
