#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

docker compose --project-directory "$SCRIPT_DIR" --env-file "$SCRIPT_DIR/.env" \
  -f "$SCRIPT_DIR/compose.yaml" --profile provider-b stop openlist
