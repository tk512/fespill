#!/bin/bash
# Bundle the game into a single distributable file: Båtspillet.love
#
# A .love file is just a ZIP of the project (with main.lua at the TOP of the
# archive). It's the robust way to hand the game to another Mac: ONE file, no
# half-finished rsync transfers, no permission problems, nothing to forget.
#
#   ./build.sh
#
# To play it on any Mac that has LÖVE installed:
#   * double-click Båtspillet.love, OR
#   * drag it onto love.app, OR
#   * /Applications/love.app/Contents/MacOS/love Båtspillet.love
#
# (LÖVE for the player can be downloaded free from https://love2d.org )

set -euo pipefail
cd "$(dirname "$0")"

OUT="Båtspillet.love"
rm -f "$OUT"

# Zip the game from the project root so main.lua / conf.lua sit at the archive
# root (LÖVE requires main.lua at the top level). Everything the game needs is
# main.lua, conf.lua, src/ and assets/. We exclude dev-only and host-specific
# stuff so the bundle stays small and clean.
zip -9 -r -X "$OUT" . \
    -x '.git/*' \
    -x '.claude/*' \
    -x 'raw/*' \
    -x 'tools/*' \
    -x 'save/*' \
    -x '*.love' \
    -x '*.app' -x '*.app/*' \
    -x '*.command' \
    -x '*.applescript' \
    -x 'sync.sh' -x 'build.sh' \
    -x 'CLAUDE.md' -x 'README.md' \
    -x '.DS_Store' -x '*/.DS_Store' \
    -x '*.swp' \
    > /dev/null

echo ">> built $OUT  ($(du -h "$OUT" | cut -f1))"
echo ">> play it:  /Applications/love.app/Contents/MacOS/love \"$OUT\""
echo ">> or double-click it (Macs with LÖVE installed associate .love files)."
