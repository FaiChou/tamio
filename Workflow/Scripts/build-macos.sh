#!/bin/bash

# Build the Mac app (Mac Catalyst, universal arm64/x86_64).
#
# Signed with the first Apple Development certificate in the keychain, so the
# signature, and the keychain's trust in it, survive rebuilds; ad hoc when
# there is none. Override with CODE_SIGN_IDENTITY / DEVELOPMENT_TEAM.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIGURATION="${1:-Debug}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/DerivedData}"

case "$CONFIGURATION" in
    Debug|Release) ;;
    *) printf 'Usage: bash %s [Debug|Release]\n' "$0" >&2; exit 2 ;;
esac

if [[ -z "${CODE_SIGN_IDENTITY:-}" ]]; then
    CODE_SIGN_IDENTITY="$(security find-identity -v -p codesigning \
        | sed -n 's/.*"\(Apple Development: [^"]*\)".*/\1/p' | head -1)"
fi
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"
if [[ "$CODE_SIGN_IDENTITY" != "-" && -z "${DEVELOPMENT_TEAM:-}" ]]; then
    DEVELOPMENT_TEAM="$(security find-certificate -c "$CODE_SIGN_IDENTITY" -p \
        | openssl x509 -noout -subject -nameopt multiline \
        | sed -n 's/^ *organizationalUnitName *= *//p' | head -1)"
fi
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}"

xcodebuild \
    -workspace "$ROOT_DIR/App.xcworkspace" \
    -scheme Rayon \
    -configuration "$CONFIGURATION" \
    -destination 'generic/platform=macOS,variant=Mac Catalyst' \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    ARCHS='arm64 x86_64' \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGNING_ALLOWED=YES \
    CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY" \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
    PROVISIONING_PROFILE_SPECIFIER= \
    build

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION-maccatalyst/Rayon.app"
/usr/bin/codesign --verify --deep --strict --all-architectures --verbose=2 "$APP_PATH"
printf '\nSigned (%s): %s\n' "$CODE_SIGN_IDENTITY" "$APP_PATH"
