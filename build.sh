#!/bin/bash
# Builds "No Dim.app".
#   ./build.sh           build only, into ./build
#   ./build.sh install   build, install to /Applications and (re)launch, leaving no other copy
#                        behind (extra copies show up in Spotlight and offer the control twice)
#   ./build.sh release   Developer ID build (hardened runtime) packaged as build/NoDim.dmg;
#                        with NOTARY_PROFILE=<notarytool keychain profile> it's notarized and stapled
# Needs Xcode 26+ and xcodegen (brew install xcodegen).
set -euo pipefail
cd "$(dirname "$0")"
MODE="${1:-}"
NAME="No Dim"
BUILD="$PWD/build"
APP="$BUILD/$NAME.app"
# ".noindex" keeps Spotlight (and so Launchpad and Control Center's gallery) away from build products.
DERIVED="$BUILD/DerivedData.noindex"
PRODUCTS="$DERIVED/Build/Products/Release"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

echo "→ Generating the Xcode project"
xcodegen generate --quiet


SIGNING=()
if [[ "$MODE" == "release" ]]; then
    # No get-task-allow (Xcode adds it for debugging; notarization rejects it).
    SIGNING=(CODE_SIGN_IDENTITY="Developer ID Application" OTHER_CODE_SIGN_FLAGS=--timestamp
             CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO)
fi

echo "→ Building"
xcodebuild -project NoDim.xcodeproj -scheme NoDim -configuration Release \
    -derivedDataPath "$DERIVED" -destination "platform=macOS" -quiet \
    ${SIGNING[@]+"${SIGNING[@]}"} build
if [[ "$MODE" != "install" ]]; then
    rm -rf "$APP"
    ditto "$PRODUCTS/$NAME.app" "$APP"
    echo "✓ Built $APP"
fi

if [[ "$MODE" == "release" ]]; then
    if codesign -d --entitlements - --xml "$APP" "$APP/Contents/PlugIns/NoDimControls.appex" 2>/dev/null | grep -q get-task-allow; then
        echo "✗ The release build still has the get-task-allow entitlement" >&2; exit 1
    fi
    echo "→ Disk image"
    DMG="$BUILD/NoDim.dmg"
    STAGE="$BUILD/dmg"
    rm -rf "$STAGE" "$DMG"
    mkdir -p "$STAGE"
    ditto "$APP" "$STAGE/$NAME.app"
    ln -s /Applications "$STAGE/Applications"
    hdiutil create -volname "$NAME" -srcfolder "$STAGE" -ov -format UDZO -quiet "$DMG"
    rm -rf "$STAGE"
    codesign --force --sign "Developer ID Application" --timestamp "$DMG"
    if [[ -n "${NOTARY_PROFILE:-}" ]]; then
        echo "→ Notarizing (a few minutes)"
        RESULT=$(xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait 2>&1 | tee /dev/stderr)
        if ! grep -q "status: Accepted" <<< "$RESULT"; then
            SUBMISSION=$(awk '/^  id:/ {print $2; exit}' <<< "$RESULT")
            echo "✗ Notarization failed. Apple's log:" >&2
            xcrun notarytool log "$SUBMISSION" --keychain-profile "$NOTARY_PROFILE" >&2 || true
            exit 1
        fi
        xcrun stapler staple "$DMG"
        echo "✓ Notarized and stapled"
    else
        echo "  Not notarized. Run with NOTARY_PROFILE=<profile> to notarize."
    fi
    echo "✓ $DMG"
fi

if [[ "$MODE" == "install" ]]; then
    echo "→ Installing to /Applications"
    # The app used to be called "Screen Awake" (same bundle ID): replace that copy, so macOS
    # doesn't see two apps offering the same control.
    pkill -x ScreenAwakeControls 2>/dev/null || true # the control's process before the IDs were renamed
    if [[ -d "/Applications/Screen Awake.app" ]]; then
        pkill -x "Screen Awake" 2>/dev/null || true
        "$LSREGISTER" -u "/Applications/Screen Awake.app" 2>/dev/null || true
        rm -rf "/Applications/Screen Awake.app"
    fi
    pkill -x "$NAME" 2>/dev/null || true
    # Control Center keeps reusing a running extension process, which still has the old code.
    pkill -x NoDimControls 2>/dev/null || true
    sleep 1 # No Dim takes half a second to switch off and update Control Center before exiting
    rm -rf "/Applications/$NAME.app"
    ditto "$PRODUCTS/$NAME.app" "/Applications/$NAME.app"
    # Keep only the installed copy: remove the build products (and anything an older version of
    # this script left in build/), and forget them in Launch Services.
    for leftover in "$PRODUCTS/$NAME.app" "$PRODUCTS/NoDimControls.appex" "$APP" \
                    "$BUILD/Screen Awake.app" "$BUILD/DerivedData/Build/Products/Release/$NAME.app" \
                    "$BUILD/DerivedData"; do
        [[ "$leftover" == *.app ]] && { "$LSREGISTER" -u "$leftover" 2>/dev/null || true; }
        rm -rf "$leftover"
    done
    "$LSREGISTER" -f "/Applications/$NAME.app"
    open "/Applications/$NAME.app" --args --background
    # Control Center keeps the old asset catalog loaded, so new or changed symbols only show up
    # after it restarts (its menu bar items blink for a moment).
    SYMBOLS_HASH=$(find Shared/Symbols.xcassets -type f -exec shasum {} + | sort | shasum | cut -c1-16)
    if [[ "$(cat "$BUILD/.symbols-installed" 2>/dev/null)" != "$SYMBOLS_HASH" ]]; then
        echo "→ Symbols changed: restarting Control Center"
        killall ControlCenter 2>/dev/null || true
        echo "$SYMBOLS_HASH" > "$BUILD/.symbols-installed"
    fi
    echo "✓ Installed and launched"
fi
