#!/bin/bash

# Prints one version's notes: its section of CHANGELOG.md, without the heading.
# The release workflow makes the GitHub release's notes and the update window's
# (see appcast.sh) from it.
#
# Usage: bash Workflow/Scripts/release-notes.sh <version>   # 0.2.0, or v0.2.0
#
# Lines wrapped in the file are joined: a release page and GitHub's renderer
# keep every line break, which would cut a bullet in two.
#
# Fails when CHANGELOG.md has no section for the version, or an empty one.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERSION="${1#v}"

notes="$(awk -v version="$VERSION" '
    /^## \[/ {
        if (found) exit
        if (index($0, "## [" version "]") == 1) { found = 1; next }
    }
    found { print }
' "$ROOT_DIR/CHANGELOG.md" | /usr/bin/python3 -c '
import re, sys
out = []
for line in sys.stdin.read().splitlines():
    starts_block = re.match(r"\s*([-*+] |\d+\. |#|>|```|\|)", line)
    if line.strip() and out and out[-1].strip() and not starts_block:
        out[-1] = out[-1].rstrip() + " " + line.strip()
    else:
        out.append(line)
print("\n".join(out).strip())
')"

if [[ -z "${notes//[[:space:]]/}" ]]; then
    printf 'CHANGELOG.md has no notes for %s: add a "## [%s] - <date>" section.\n' "$VERSION" "$VERSION" >&2
    exit 1
fi
printf '%s\n' "$notes"
