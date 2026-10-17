#!/bin/bash

# Build the Mac app (Mac Catalyst, universal arm64/x86_64).
#
# Signed ad hoc, so a local build never asks for the keychain. The Release
# workflow passes its Developer ID through CODE_SIGN_IDENTITY (and
# DEVELOPMENT_TEAM, else read from the certificate).
#
# With a provisioning profile made for the app's bundle id and that
# certificate, the app is also signed for iCloud's key-value store, which the
# system only grants with one. It is looked for by provisioning-profile.sh;
# MAC_PROVISIONING_PROFILE names one outright.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIGURATION="${1:-Debug}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/DerivedData}"

case "$CONFIGURATION" in
    Debug|Release) ;;
    *) printf 'Usage: bash %s [Debug|Release]\n' "$0" >&2; exit 2 ;;
esac

CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"
if [[ "$CODE_SIGN_IDENTITY" != "-" && -z "${DEVELOPMENT_TEAM:-}" ]]; then
    DEVELOPMENT_TEAM="$(security find-certificate -c "$CODE_SIGN_IDENTITY" -p \
        | openssl x509 -noout -subject -nameopt multiline \
        | sed -n 's/^ *organizationalUnitName *= *//p' | head -1)"
fi
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}"

xcodebuild \
    -workspace "$ROOT_DIR/App.xcworkspace" \
    -scheme Tamio \
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

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION-maccatalyst/Tamio.app"

# The profile goes into the app, and what it grants into the signature: the
# app asks its own signature whether it may sync.
sign_for_icloud() {
    [[ "$CODE_SIGN_IDENTITY" != "-" && -n "$DEVELOPMENT_TEAM" ]] || return 0
    local bundle_id profile grants entitlements key signature options=()
    bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Contents/Info.plist")"
    profile="${MAC_PROVISIONING_PROFILE:-$(bash "$ROOT_DIR/Workflow/Scripts/provisioning-profile.sh" \
        provisionprofile "$DEVELOPMENT_TEAM" "$bundle_id" "$CODE_SIGN_IDENTITY")}"
    [[ -n "$profile" ]] || return 0
    # Read whole before it is searched: a search that stops at the first match
    # would fail the pipe.
    grants="$(security cms -D -i "$profile" 2>/dev/null || true)"
    [[ "$grants" == *com.apple.developer.ubiquity-kvstore-identifier* ]] || return 0

    entitlements="$(mktemp)"
    /usr/bin/codesign -d --entitlements - --xml "$APP_PATH" 2>/dev/null > "$entitlements"
    for key in com.apple.application-identifier com.apple.developer.ubiquity-kvstore-identifier; do
        /usr/libexec/PlistBuddy -c "Delete :$key" "$entitlements" 2>/dev/null || true
        /usr/libexec/PlistBuddy -c "Add :$key string $DEVELOPMENT_TEAM.$bundle_id" "$entitlements"
    done
    /usr/libexec/PlistBuddy -c 'Delete :com.apple.developer.team-identifier' "$entitlements" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :com.apple.developer.team-identifier string $DEVELOPMENT_TEAM" "$entitlements"

    cp "$profile" "$APP_PATH/Contents/embedded.provisionprofile"
    signature="$(/usr/bin/codesign -d --verbose=2 "$APP_PATH" 2>&1 || true)"
    [[ "$signature" == *"(runtime)"* ]] && options=(--options runtime)
    /usr/bin/codesign --force --sign "$CODE_SIGN_IDENTITY" ${options[@]+"${options[@]}"} --timestamp=none \
        --entitlements "$entitlements" "$APP_PATH"
    rm -f "$entitlements"
    printf 'Signed for iCloud with %s\n' "$(basename "$profile")"
}
sign_for_icloud

/usr/bin/codesign --verify --deep --strict --all-architectures --verbose=2 "$APP_PATH"
printf '\nSigned (%s): %s\n' "$CODE_SIGN_IDENTITY" "$APP_PATH"
