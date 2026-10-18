#!/bin/bash
# Renders og/card.html to public/og.png (1200×630) in dark, at twice the size
# and scaled down, so the link preview is sharp. Needs Google Chrome and
# ImageMagick.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
site="$(dirname "$here")/public"
work="$(mktemp -d)"
cp -R "$site/." "$work/" && cp "$here/card.html" "$work/card.html"

# The card loads the site's files from a local server, as the site does.
port=8791
python3 -m http.server "$port" --bind 127.0.0.1 --directory "$work" >/dev/null 2>&1 &
server=$!
disown "$server"
trap 'kill "$server" 2>/dev/null || true; rm -rf "$work"' EXIT
sleep 1

"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --hide-scrollbars \
    --blink-settings=preferredColorScheme=0 --force-device-scale-factor=2 --window-size=1200,630 \
    --virtual-time-budget=6000 --screenshot="$work/og@2x.png" "http://127.0.0.1:$port/card.html" >/dev/null 2>&1
magick "$work/og@2x.png" -filter Lanczos -resize 1200x630 -strip -define png:compression-level=9 "$site/og.png"
echo "wrote $site/og.png"
