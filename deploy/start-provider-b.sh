#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

set -a
# shellcheck disable=SC1091
. "$SCRIPT_DIR/.env"
set +a

: "${LITTLELIFE_ROOT:=/mnt/mmcblk0p6/littlelife}"
: "${EXPECTED_MOUNT:=/mnt/mmcblk0p6}"

EXPECTED_MOUNT="$EXPECTED_MOUNT" LITTLELIFE_ROOT="$LITTLELIFE_ROOT" \
  "$PROJECT_DIR/scripts/preflight-mount.sh"

directory="$LITTLELIFE_ROOT/runtime/openlist"
mkdir -p "$directory"
chown 1001:1001 "$directory"
chmod 0700 "$directory"

export LITTLELIFE_ROOT
docker compose --project-directory "$SCRIPT_DIR" --env-file "$SCRIPT_DIR/.env" \
  -f "$SCRIPT_DIR/compose.yaml" --profile provider-b up -d openlist

echo "Provider B bridge started on ${LITTLELIFE_BIND_ADDRESS:-127.0.0.1}:${OPENLIST_HTTP_PORT:-5244}."
