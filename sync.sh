#!/bin/bash
# Sync the game between this machine and the remote (e.g. the Yosemite Mac).
#
#   ./sync.sh push   local  -> remote   (mirror; deletes remote files you removed locally)
#   ./sync.sh pull   remote -> local    (brings back assets added on the remote; never deletes)
#   ./sync.sh both   pull, then push    (default: grab remote changes, then publish local)
#
# WHY two directions instead of one --delete command:
#   rsync --delete makes the destination an exact copy of the source. Run it the
#   wrong way and it deletes files the *other* side added. So:
#     * push uses --delete  (local is the source of truth for CODE + deletions)
#     * pull does NOT --delete (so a stray local file is never wiped by a pull)
#     * both = pull first, then push, so assets added on the remote are copied
#       here before the mirroring push runs.
#
#   NOTE: because `both` pulls first, deleting a file *locally* and running
#   `both` will re-copy it from the remote. To actually propagate a local
#   deletion, run `./sync.sh push` on its own.
#
#   For real conflict-aware two-way sync (handles edits on both sides + renames),
#   use `unison` instead — see the bottom of this file.

set -euo pipefail

REMOTE="${FESPILL_REMOTE:-steve:/data/fespill}"
DIR="$(cd "$(dirname "$0")" && pwd)"

# Things that must NOT sync:
#   *.app        — built per-machine/arch (an arm64 applet would break on Intel)
#   .DS_Store    — macOS Finder junk
#   savegame.json— the in-repo one is illustrative; real saves live in LÖVE's
#                  app-data folder anyway, so don't clobber across machines
EXCLUDES=(--exclude '.DS_Store' --exclude '*.app' --exclude '.git'
          --exclude '.claude' --exclude '*.swp' --exclude 'save/savegame.json')

pull() {
    echo ">> pull  $REMOTE/  ->  $DIR/   (no delete)"
    rsync -av "${EXCLUDES[@]}" "$REMOTE/" "$DIR/"
}
push() {
    echo ">> push  $DIR/  ->  $REMOTE/   (mirror, --delete)"
    rsync -av --delete "${EXCLUDES[@]}" "$DIR/" "$REMOTE/"
}

case "${1:-both}" in
    push) push ;;
    pull) pull ;;
    both) pull; push ;;
    *) echo "usage: $0 [push|pull|both]"; exit 1 ;;
esac
echo ">> done."

# ── Proper two-way alternative (optional) ───────────────────────────────────
# Install unison on both machines (matching versions), then:
#   unison "$DIR" "ssh://steve//data/fespill" \
#     -ignore 'Name *.app' -ignore 'Name .DS_Store' -auto -batch
# It tracks state, so it propagates additions, deletions AND renames both ways
# and flags genuine conflicts instead of clobbering.
