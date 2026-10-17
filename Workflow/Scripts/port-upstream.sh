#!/bin/bash

# Brings commits from Rayon (the `upstream` remote) into Tamio: each commit is
# exported as a patch, renamed with tamio-rename.py, then applied with a 3-way
# merge so conflicts are left for review.
#
# Usage:
#   bash Workflow/Scripts/port-upstream.sh <commit-or-range>   # e.g. 02b313a..upstream/main

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RANGE="${1:?Usage: port-upstream.sh <commit-or-range>}"
[[ "$RANGE" == *..* ]] || RANGE="$RANGE^!"

cd "$ROOT_DIR"
git fetch upstream
patch="$(mktemp)"
git format-patch --stdout "$RANGE" | python3 -I Workflow/Scripts/tamio-rename.py text > "$patch"
git am -3 "$patch" || {
    printf 'Conflicts: resolve them, then `git am --continue` (or `git am --abort`).\n' >&2
    exit 1
}
rm -f "$patch"
