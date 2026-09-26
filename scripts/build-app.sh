#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="Prompt Manager"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
BUNDLE_ID="co.aipieksel.prompt-manager.mac"
EXECUTABLE_NAME="PromptManager"
INFO_PLIST="$PROJECT_DIR/Sources/PromptManager/Info.plist"
LOCAL_CONFIG="$PROJECT_DIR/local.config"
if [ -f "$LOCAL_CONFIG" ]; then
    # shellcheck source=/dev/null
    source "$LOCAL_CONFIG"
fi
SIGNING_IDENTITY="${SIGNING_IDENTITY:-${PROMPT_MANAGER_CODESIGN_IDENTITY:-}}"
LOCAL_SIGNING_IDENTITY_NAME="${LOCAL_SIGNING_IDENTITY_NAME:-Prompt Manager Local Code Signing}"

find_codesign_identity() {
    local exact_identity apple_identity first_identity

    exact_identity="$(security find-identity -v -p codesigning 2>/dev/null | awk -v name="$LOCAL_SIGNING_IDENTITY_NAME" 'index($0, "\"" name "\"") { sub(/^[[:space:]]*[0-9]+\\) /, ""); sub(/[[:space:]]+"[^"]+"$/, ""); print; exit }' || true)"
    if [ -n "$exact_identity" ]; then
        printf '%s\n' "$LOCAL_SIGNING_IDENTITY_NAME"
        return
    fi

    apple_identity="$(security find-identity -v -p codesigning 2>/dev/null | awk '/"Apple Development:|Developer ID Application:|Mac Developer:/ { match($0, /"[^"]+"/); if (RSTART > 0) { print substr($0, RSTART + 1, RLENGTH - 2); exit } }' || true)"
    if [ -n "$apple_identity" ]; then
        printf '%s\n' "$apple_identity"
        return
    fi

    first_identity="$(security find-identity -v -p codesigning 2>/dev/null | awk '/[0-9]+ valid identities found/ { next } /"/ { match($0, /"[^"]+"/); if (RSTART > 0) { print substr($0, RSTART + 1, RLENGTH - 2); exit } }' || true)"
    if [ -n "$first_identity" ]; then
        printf '%s\n' "$first_identity"
    fi
}

if [ -z "$SIGNING_IDENTITY" ]; then
    SIGNING_IDENTITY="$(find_codesign_identity)"
fi
if [ -z "$SIGNING_IDENTITY" ]; then
    SIGNING_IDENTITY="-"
fi

bump_patch_version() {
    local current_version next_version major minor patch
    current_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST" 2>/dev/null || echo 0.1.0)"
    if [[ "$current_version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
        major="${BASH_REMATCH[1]}"
        minor="${BASH_REMATCH[2]}"
        patch="${BASH_REMATCH[3]}"
        next_version="$major.$minor.$((patch + 1))"
    elif [[ "$current_version" =~ ^([0-9]+)\.([0-9]+)$ ]]; then
        major="${BASH_REMATCH[1]}"
        minor="${BASH_REMATCH[2]}"
        next_version="$major.$minor.1"
    else
        next_version="0.1.1"
    fi
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $next_version" "$INFO_PLIST"
}

bump_build_number() {
    local current_build next_build
    current_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST" 2>/dev/null || echo 0)"
    if [[ "$current_build" =~ ^[0-9]+$ ]]; then
        next_build=$((current_build + 1))
    else
        next_build=1
    fi
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $next_build" "$INFO_PLIST"
}

bump_version_numbers() {
    bump_patch_version
    bump_build_number
}

bump_version_numbers
APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
APP_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"

quit_running_app() {
    echo "🛑 Closing running app if needed..."
    osascript <<OSA >/dev/null 2>&1 || true
tell application "System Events"
    if exists application process "$APP_NAME" then
        tell application id "$BUNDLE_ID" to quit
    end if
end tell
OSA
    for _ in {1..20}; do
        if ! pgrep -x "$APP_NAME" >/dev/null 2>&1 && ! pgrep -x "$EXECUTABLE_NAME" >/dev/null 2>&1; then
            return
        fi
        sleep 0.5
    done
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
    pkill -x "$EXECUTABLE_NAME" >/dev/null 2>&1 || true
    pkill -f "$EXECUTABLE_NAME" >/dev/null 2>&1 || true
    sleep 1
}

quit_running_app

echo "🔨 Building $APP_NAME $APP_VERSION ($APP_BUILD)..."
cd "$PROJECT_DIR"
swift build -c release
EXECUTABLE="$(swift build -c release --show-bin-path)/$EXECUTABLE_NAME"
if [ ! -f "$EXECUTABLE" ]; then
    echo "❌ Build failed — executable not found: $EXECUTABLE"
    exit 1
fi

echo "📦 Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
cp "$INFO_PLIST" "$APP_BUNDLE/Contents/Info.plist"
if [ -d "$PROJECT_DIR/Sources/PromptManager/Resources" ]; then
    cp -R "$PROJECT_DIR/Sources/PromptManager/Resources/." "$APP_BUNDLE/Contents/Resources/"
fi
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $APP_BUILD" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $APP_VERSION" "$APP_BUNDLE/Contents/Info.plist"
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

ENTITLEMENTS="$BUILD_DIR/PromptManager.entitlements"
cat > "$ENTITLEMENTS" <<ENTITLEMENTS_XML
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
</dict>
</plist>
ENTITLEMENTS_XML

if [ "$SIGNING_IDENTITY" = "-" ]; then
    echo "🔏 Signing with ad-hoc identity"
    echo "⚠️  No stable code-signing identity was found. macOS Keychain may ask again after every rebuild."
    echo "   Fix: create/use a local signing certificate and set SIGNING_IDENTITY in local.config."
else
    echo "🔏 Signing with: $SIGNING_IDENTITY"
fi
codesign --force --sign "$SIGNING_IDENTITY" --entitlements "$ENTITLEMENTS" "$APP_BUNDLE"
codesign --verify --verbose "$APP_BUNDLE" && echo "✅ Signature valid"

echo "🚀 Opening app..."
open "$APP_BUNDLE"
echo "✅ Built, signed, and opened: $APP_BUNDLE"
echo "Version: $APP_VERSION ($APP_BUILD)"
