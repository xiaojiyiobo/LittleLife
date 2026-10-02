#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if [ -f "$SCRIPT_DIR/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$SCRIPT_DIR/.env"
  set +a
fi

docker compose --project-directory "$SCRIPT_DIR" --env-file "$SCRIPT_DIR/.env" \
  -f "$SCRIPT_DIR/compose.yaml" down

