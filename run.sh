#!/usr/bin/env bash
set -euo pipefail

PORT=8731
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
URL="http://localhost:${PORT}"

cd "$DIR"

cleanup() {
  [[ -n "${SERVER_PID:-}" ]] && kill "$SERVER_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

echo "Serving $DIR at $URL"
python3 -m http.server "$PORT" &
SERVER_PID=$!

# Give the server a moment, then open the game in the default browser.
sleep 1
xdg-open "$URL" >/dev/null 2>&1 || echo "Open $URL in your browser."

echo "Press Ctrl+C to stop the server."
wait "$SERVER_PID"