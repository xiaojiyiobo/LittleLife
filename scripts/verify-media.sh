#!/bin/sh
set -eu

: "${LITTLELIFE_ROOT:=/mnt/mmcblk0p6/littlelife}"
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
EXPECTED_MOUNT=${EXPECTED_MOUNT:-/mnt/mmcblk0p6} LITTLELIFE_ROOT="$LITTLELIFE_ROOT" \
  "$SCRIPT_DIR/preflight-mount.sh"

manifest="$LITTLELIFE_ROOT/data/manifests/media-sha256.txt"
[ -r "$manifest" ] || { echo "ERROR: media manifest is unreadable" >&2; exit 95; }
(cd "$LITTLELIFE_ROOT/data" && sha256sum -c "manifests/media-sha256.txt")
