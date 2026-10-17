#!/bin/bash

# Puts Sparkle (the Mac app's updater) in External/Sparkle: Sparkle.framework,
# which the MacBridge bundle links and carries, and the tools in bin/ that
# sign updates (sign_update). Fetched once, checked against its checksum, and
# kept until SPARKLE_VERSION changes. The build runs this; so can you.

set -euo pipefail

SPARKLE_VERSION=2.6.4
SPARKLE_SHA256=50612a06038abc931f16011d7903b8326a362c1074dabccb718404ce8e585f0b

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEST="$ROOT_DIR/External/Sparkle"
STAMP="$DEST/.version"

if [[ -f "$STAMP" && "$(cat "$STAMP")" == "$SPARKLE_VERSION" && -d "$DEST/Sparkle.framework" ]]; then
    exit 0
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
curl -fsSL --retry 3 -o "$work/sparkle.tar.xz" \
    "https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz"
if [[ "$(shasum -a 256 "$work/sparkle.tar.xz" | awk '{print $1}')" != "$SPARKLE_SHA256" ]]; then
    printf 'Sparkle %s does not match its checksum.\n' "$SPARKLE_VERSION" >&2
    exit 1
fi
mkdir -p "$work/x"
tar -xJf "$work/sparkle.tar.xz" -C "$work/x"
rm -rf "$DEST"
mkdir -p "$DEST"
mv "$work/x/Sparkle.framework" "$work/x/bin" "$work/x/LICENSE" "$DEST/"
printf '%s' "$SPARKLE_VERSION" > "$STAMP"
printf 'Sparkle %s in %s\n' "$SPARKLE_VERSION" "$DEST"
