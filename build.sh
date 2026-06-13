#!/bin/bash
# Build distributables for Båtspillet:
#   1. Båtspillet.love           — the game as one LÖVE file (needs LÖVE installed)
#   2. Båtspillet.app + .dmg      — UNIVERSAL app (LÖVE 11.5, arm64+Intel) to hand out
#   3. Båtspillet-Yosemite.app    — Intel app (LÖVE 11.3) for the old 2009/Yosemite iMac
#
#   ./build.sh
#
# It finds the two LÖVE builds (a .zip or an unpacked love.app). Defaults look in
# ~/Downloads for the official zips; override with env vars:
#   LOVE_UNIVERSAL=/path/love-11.5  LOVE_YOSEMITE=/path/love-11.3  ./build.sh
#
# The apps are unsigned (no Apple Developer account), so the FIRST launch on
# another Mac is: right-click the app -> Open -> Open.

set -euo pipefail
cd "$(dirname "$0")"

NAME="Båtspillet"
LOVE="$NAME.love"
LOVE_UNIVERSAL="${LOVE_UNIVERSAL:-$HOME/Downloads/love-11.5-macos.zip}"
LOVE_YOSEMITE="${LOVE_YOSEMITE:-$HOME/Downloads/love-11.3-macos.zip}"

TMPDIRS=()
cleanup() { for d in "${TMPDIRS[@]:-}"; do [ -n "${d:-}" ] && rm -rf "$d"; done; }
trap cleanup EXIT

# Resolve a love.app from a path that may be a .app, a .zip, or a folder. Echoes
# the love.app path (nothing if the source isn't there).
resolve_love() {
    local p="$1"
    [ -e "$p" ] || return 0
    if [ -d "$p" ] && [[ "$p" == *.app ]]; then echo "$p"; return 0; fi
    if [[ "$p" == *.zip ]] && [ -f "$p" ]; then
        local d; d="$(mktemp -d)"; TMPDIRS+=("$d")
        unzip -q "$p" -d "$d"
        find "$d" -maxdepth 2 -name love.app -type d -print -quit
        return 0
    fi
    [ -d "$p" ] && find "$p" -maxdepth 2 -name love.app -type d -print -quit
}

plist() { /usr/libexec/PlistBuddy -c "$1" "$2" 2>/dev/null || true; }

# Build <appname>.app from a love.app, with our .love inside and our identity.
make_app() {
    local app="$1" loveapp="$2"
    rm -rf "$app"
    cp -R "$loveapp" "$app"
    cp "$LOVE" "$app/Contents/Resources/"
    local pl="$app/Contents/Info.plist"
    plist "Set :CFBundleName $NAME" "$pl"
    plist "Set :CFBundleIdentifier com.tk.batspillet" "$pl"
    plist "Delete :CFBundleDocumentTypes" "$pl"        # don't pose as a ".love opener"
    plist "Delete :UTExportedTypeDeclarations" "$pl"
    codesign --force --deep --sign - "$app" 2>/dev/null || true  # ad-hoc (avoids "damaged")
    xattr -cr "$app" 2>/dev/null || true
    echo ">> built $app  (arch: $(lipo -archs "$app/Contents/MacOS/love" 2>/dev/null || echo '?'))"
}

# ── 1) the .love ────────────────────────────────────────────────────────────
rm -f "$LOVE"
zip -9 -r -X "$LOVE" . \
    -x '.git/*' -x '.claude/*' -x 'raw/*' -x 'tools/*' -x 'save/*' \
    -x '*.love' -x '*.app' -x '*.app/*' -x '*.dmg' \
    -x '*.command' -x '*.applescript' \
    -x 'sync.sh' -x 'build.sh' -x 'CLAUDE.md' -x 'README.md' \
    -x '.DS_Store' -x '*/.DS_Store' -x '*.swp' \
    > /dev/null
echo ">> built $LOVE  ($(du -h "$LOVE" | cut -f1))"

# ── 2) universal app + dmg (LÖVE 11.5) ──────────────────────────────────────
U="$(resolve_love "$LOVE_UNIVERSAL")"
if [ -n "$U" ]; then
    make_app "$NAME.app" "$U"
    case "$(lipo -archs "$NAME.app/Contents/MacOS/love" 2>/dev/null)" in
        *arm64*) : ;;
        *) echo "   !! WARNING: $LOVE_UNIVERSAL is not universal — won't run native on Apple Silicon." ;;
    esac
    STAGE="$(mktemp -d)"; TMPDIRS+=("$STAGE")
    cp -R "$NAME.app" "$STAGE/"
    ln -s /Applications "$STAGE/Applications"
    rm -f "$NAME.dmg"
    if hdiutil create -volname "$NAME" -srcfolder "$STAGE" -ov -format UDZO "$NAME.dmg" >/dev/null 2>&1; then
        echo ">> built $NAME.dmg  ($(du -h "$NAME.dmg" | cut -f1))"
    else
        echo ">> NOTE: hdiutil failed — $NAME.app is ready, but no .dmg."
    fi
else
    echo ">> NOTE: universal LÖVE not found ($LOVE_UNIVERSAL) — skipped $NAME.app/.dmg"
fi

# ── 3) Yosemite app (Intel LÖVE 11.3) ───────────────────────────────────────
Y="$(resolve_love "$LOVE_YOSEMITE")"
if [ -n "$Y" ]; then
    make_app "$NAME-Yosemite.app" "$Y"
else
    echo ">> NOTE: Intel/11.3 LÖVE not found ($LOVE_YOSEMITE) — skipped $NAME-Yosemite.app"
fi

echo ">> done."
echo ">> FIRST RUN on another Mac (unsigned): right-click the app -> Open -> Open."
echo "   If macOS still refuses:  xattr -dr com.apple.quarantine \"/path/to/app\""
