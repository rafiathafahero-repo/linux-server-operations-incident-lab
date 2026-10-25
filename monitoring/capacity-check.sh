#!/usr/bin/env bash
# Reconstructed from visible lab script/screenshots, not an exported copy.
set -euo pipefail
TARGET="$HOME/server-ops-lab/capacity-test"
THRESHOLD=80
TIME="$(date --iso-8601=seconds)"

FSTYPE="$(findmnt -n -M "$TARGET" -o FSTYPE 2>/dev/null || true)"
if [[ "$FSTYPE" != "tmpfs" ]]; then
    echo "[$TIME] ERROR: Expected tmpfs mount not found"
    exit 3
fi
USAGE="$(LC_ALL=C df --output=pcent -- "$TARGET" | awk 'NR==2 {gsub(/%/, "", $1); print $1}')"
if [[ ! "$USAGE" =~ ^[0-9]+$ ]]; then
    echo "[$TIME] ERROR: Cannot read filesystem usage"
    exit 3
fi
if (( USAGE >= THRESHOLD )); then
    echo "[$TIME] CRITICAL: Filesystem usage ${USAGE}% (threshold ${THRESHOLD}%)"
    exit 2
fi

echo "[$TIME] OK: Filesystem usage ${USAGE}% (threshold ${THRESHOLD}%)"
exit 0
