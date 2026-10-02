#!/bin/sh
set -eu

: "${LITTLELIFE_ROOT:=/mnt/mmcblk0p6/littlelife}"
: "${GRAV_IMAGE:?Set GRAV_IMAGE to the pinned multi-architecture image}"
: "${PUID:=1000}"
: "${PGID:=1000}"
: "${TZ:=Asia/Hong_Kong}"

runtime="$LITTLELIFE_ROOT/runtime/grav-config"
marker="$runtime/.littlelife-runtime-initialized"
container="littlelife-grav-bootstrap"

if [ -f "$marker" ]; then
  exit 0
fi

if [ -n "$(find "$runtime" -mindepth 1 -maxdepth 1 -print 2>/dev/null | head -n 1)" ]; then
  echo "ERROR: Grav runtime is non-empty but has no initialization marker: $runtime" >&2
  echo "Move it aside for inspection; this script will not overwrite it." >&2
  exit 25
fi

mkdir -p "$runtime"
if docker inspect "$container" >/dev/null 2>&1; then
  echo "ERROR: bootstrap container already exists: $container" >&2
  exit 26
fi

cleanup() {
  docker stop "$container" >/dev/null 2>&1 || true
}
trap cleanup EXIT HUP INT TERM

docker run -d --rm \
  --name "$container" \
  --network none \
  -e "PUID=$PUID" -e "PGID=$PGID" -e "TZ=$TZ" \
  -v "$runtime:/config" \
  "$GRAV_IMAGE" >/dev/null

ready=no
attempt=0
while [ "$attempt" -lt 60 ]; do
  if [ -d "$runtime/www/user/plugins" ] && [ -d "$runtime/www/user/config" ]; then
    ready=yes
    break
  fi
  if [ "$(docker inspect -f '{{.State.Running}}' "$container" 2>/dev/null || echo false)" != true ]; then
    break
  fi
  sleep 1
  attempt=$((attempt + 1))
done

if [ "$ready" != yes ]; then
  echo "ERROR: Grav runtime initialization did not complete" >&2
  docker logs "$container" >&2 || true
  exit 27
fi

docker stop "$container" >/dev/null
trap - EXIT HUP INT TERM
printf '%s\n' "image=$GRAV_IMAGE" "initialized_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$marker"
echo "Initialized Grav runtime without exposing a network port: $runtime"

