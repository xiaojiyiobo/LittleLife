#!/bin/sh
set -eu

: "${LITTLELIFE_TEST_URL:=http://127.0.0.1:18080}"
: "${LITTLELIFE_TEST_CONTAINER:=littlelife-grav}"

attempt=0
while [ "$attempt" -lt 90 ]; do
  health=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' \
    "$LITTLELIFE_TEST_CONTAINER" 2>/dev/null || true)
  [ "$health" = healthy ] && break
  sleep 1
  attempt=$((attempt + 1))
done

if [ "${health:-}" != healthy ]; then
  echo "ERROR: container did not become healthy (last state: ${health:-missing})" >&2
  docker logs --tail 120 "$LITTLELIFE_TEST_CONTAINER" >&2 || true
  exit 60
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM

fetch() {
  label=$1
  path=$2
  output=$3
  code=$(curl -sS -o "$output" -w '%{http_code}' "$LITTLELIFE_TEST_URL$path")
  if [ "$code" != 200 ]; then
    echo "ERROR: $label returned HTTP $code" >&2
    exit 61
  fi
  echo "$label=200"
}

fetch HOME / "$work/home"
fetch TIMELINE /timeline "$work/timeline"
fetch STORY /archive/2026/20261002-first-smile "$work/story"
fetch MEDIA /user/pages/02.archive/2026/20261002-first-smile/sample.svg "$work/media"

grep -Fq 'PRIVATE FAMILY ARCHIVE' "$work/home"
grep -Fq '第一次微笑' "$work/timeline"
grep -Fq '这是用于验证 LittleLife' "$work/story"
grep -Fq '<svg ' "$work/media"

blocked=$(curl -sS -o /dev/null -w '%{http_code}' \
  "$LITTLELIFE_TEST_URL/user/pages/02.archive/2026/20261002-first-smile/story.md")
if [ "$blocked" != 403 ]; then
  echo "ERROR: source Markdown was not blocked (HTTP $blocked)" >&2
  exit 62
fi

echo "MARKDOWN_DIRECT_ACCESS=403"
echo "CONTAINER_SMOKE=ok"
