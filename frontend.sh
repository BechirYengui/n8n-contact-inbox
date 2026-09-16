#!/usr/bin/env bash
# Serve the demo frontend on http://localhost:8080 (localhost only).
# n8n must be running (./start.sh) for the page to work.
set -euo pipefail

PORT="${FRONTEND_PORT:-8080}"

echo "Frontend: http://localhost:$PORT"
exec python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$(dirname "$0")/frontend"
