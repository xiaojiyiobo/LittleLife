#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

if [ -f "$SCRIPT_DIR/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$SCRIPT_DIR/.env"
  set +a
fi

: "${LITTLELIFE_ROOT:=/mnt/mmcblk0p6/littlelife}"
: "${EXPECTED_MOUNT:=/mnt/mmcblk0p6}"

EXPECTED_MOUNT="$EXPECTED_MOUNT" LITTLELIFE_ROOT="$LITTLELIFE_ROOT" \
  "$PROJECT_DIR/scripts/preflight-mount.sh"

if [ ! -f "$LITTLELIFE_ROOT/derived/grav-pages/.littlelife-derived" ]; then
  echo "ERROR: generated Grav pages are missing; build and validate them before startup" >&2
  exit 23
fi

for directory in \
  "$LITTLELIFE_ROOT/runtime/grav-config" \
  "$LITTLELIFE_ROOT/backup/logs" \
  "$LITTLELIFE_ROOT/backup/locks"; do
  mkdir -p "$directory"
  chmod 0750 "$directory"
done

export LITTLELIFE_ROOT
"$SCRIPT_DIR/bootstrap-runtime.sh"

docker compose --project-directory "$SCRIPT_DIR" --env-file "$SCRIPT_DIR/.env" \
  -f "$SCRIPT_DIR/compose.yaml" up -d

echo "LittleLife started on ${LITTLELIFE_BIND_ADDRESS:-127.0.0.1}:${LITTLELIFE_HTTP_PORT:-8080}."

