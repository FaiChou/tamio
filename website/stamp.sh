#!/bin/bash
# Stamps each stylesheet and script link in public/*.html with its file's
# hash (?v=…), so a change reaches visitors at once. Run before deploying.
set -euo pipefail
cd "$(dirname "$0")/public"
for asset in styles.css demo.css main.js demo.js; do
    hash=$(shasum -a 256 "$asset" | cut -c1-10)
    for page in *.html; do
        sed -E -i '' "s#/${asset}(\\?v=[0-9a-f]+)?\"#/${asset}?v=${hash}\"#g" "$page"
    done
done
grep -ho '/[a-z]*\.\(css\|js\)?v=[0-9a-f]*' *.html | sort -u
