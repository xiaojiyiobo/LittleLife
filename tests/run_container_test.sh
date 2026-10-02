#!/bin/sh
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
: "${LITTLELIFE_ROOT:?Point LITTLELIFE_ROOT at the disposable test stage}"
: "${GRAV_IMAGE:?Set the pinned image reference}"
: "${LITTLELIFE_HTTP_PORT:=18080}"
: "${PUID:=1000}"
: "${PGID:=1000}"
: "${TZ:=Asia/Hong_Kong}"
: "${GRAV_MEMORY_LIMIT:=512m}"
: "${GRAV_CPU_LIMIT:=1.0}"

export LITTLELIFE_ROOT GRAV_IMAGE LITTLELIFE_HTTP_PORT PUID PGID TZ
export GRAV_MEMORY_LIMIT GRAV_CPU_LIMIT

cleanup() {
  docker compose --project-directory "$PROJECT_DIR/deploy" \
    -f "$PROJECT_DIR/deploy/compose.yaml" down >/dev/null 2>&1 || true
}
trap cleanup EXIT HUP INT TERM

docker compose --project-directory "$PROJECT_DIR/deploy" \
  -f "$PROJECT_DIR/deploy/compose.yaml" up -d

LITTLELIFE_TEST_URL="http://127.0.0.1:$LITTLELIFE_HTTP_PORT" \
  "$PROJECT_DIR/tests/smoke_container.sh"
