#!/bin/sh
set -eu

: "${LITTLELIFE_ROOT:=/mnt/mmcblk0p6/littlelife}"
: "${LITTLELIFE_URL:=http://127.0.0.1:8080}"
: "${LITTLELIFE_ADMIN_USER:=littlelife}"
: "${LITTLELIFE_ADMIN_PASSWORD_FILE:=$LITTLELIFE_ROOT/secrets/admin-password.txt}"

tmp=$(mktemp -d /tmp/littlelife-acl.XXXXXX)
trap 'rm -rf "$tmp"' EXIT INT TERM

password=$(sed -n '1p' "$LITTLELIFE_ADMIN_PASSWORD_FILE")
printf '%s' "$password" | docker exec -i littlelife-grav php -r '
$password = stream_get_contents(STDIN);
echo json_encode(["username" => $argv[1], "password" => $password], JSON_UNESCAPED_SLASHES);
' "$LITTLELIFE_ADMIN_USER" > "$tmp/login-request.json"
unset password

login_code=$(curl -sS -o "$tmp/login-response.json" -w '%{http_code}' \
  -X POST "$LITTLELIFE_URL/api/v1/auth/token" \
  -H 'Content-Type: application/json' \
  --data-binary "@$tmp/login-request.json")
[ "$login_code" = 200 ] || { echo "FAIL auth/token HTTP $login_code" >&2; exit 1; }

token=$(docker exec -i littlelife-grav php -r '
$body = json_decode(stream_get_contents(STDIN), true);
$token = $body["data"]["access_token"] ?? "";
if (!is_string($token) || $token === "") { exit(1); }
echo $token;
' < "$tmp/login-response.json")

entries_code=$(curl -sS -o "$tmp/entries.json" -w '%{http_code}' \
  -H "X-API-Token: $token" "$LITTLELIFE_URL/api/v1/littlelife/entries")
[ "$entries_code" = 200 ] || { echo "FAIL littlelife/entries HTTP $entries_code" >&2; exit 1; }

rebuild_code=$(curl -sS -o "$tmp/rebuild.json" -w '%{http_code}' \
  -X POST -H "X-API-Token: $token" -H 'Content-Type: application/json' \
  --data '{}' "$LITTLELIFE_URL/api/v1/littlelife/rebuild")
[ "$rebuild_code" = 200 ] || { echo "FAIL littlelife/rebuild HTTP $rebuild_code" >&2; exit 1; }

pages_code=$(curl -sS -o "$tmp/pages.json" -w '%{http_code}' \
  -H "X-API-Token: $token" "$LITTLELIFE_URL/api/v1/pages")
[ "$pages_code" = 403 ] || { echo "FAIL pages expected 403, got $pages_code" >&2; exit 1; }

users_code=$(curl -sS -o "$tmp/users.json" -w '%{http_code}' \
  -H "X-API-Token: $token" "$LITTLELIFE_URL/api/v1/users")
[ "$users_code" = 200 ] || { echo "FAIL users self-view HTTP $users_code" >&2; exit 1; }
docker exec -i littlelife-grav php -r '
$body = json_decode(stream_get_contents(STDIN), true);
$rows = $body["data"] ?? null;
if (!is_array($rows) || count($rows) !== 1 || ($rows[0]["username"] ?? "") !== $argv[1]) { exit(1); }
' "$LITTLELIFE_ADMIN_USER" < "$tmp/users.json" || {
  echo 'FAIL users endpoint exposed more than the authenticated account' >&2
  exit 1
}

users_filters_code=$(curl -sS -o "$tmp/users-filters.json" -w '%{http_code}' \
  -H "X-API-Token: $token" "$LITTLELIFE_URL/api/v1/users/filters")
[ "$users_filters_code" = 403 ] || {
  echo "FAIL users/filters expected 403, got $users_filters_code" >&2
  exit 1
}

anonymous_code=$(curl -sS -o "$tmp/anonymous.json" -w '%{http_code}' \
  "$LITTLELIFE_URL/api/v1/littlelife/entries")
[ "$anonymous_code" = 401 ] || { echo "FAIL anonymous expected 401, got $anonymous_code" >&2; exit 1; }

admin_code=$(curl -sS -o /dev/null -w '%{http_code}' "$LITTLELIFE_URL/admin2")
[ "$admin_code" = 200 ] || { echo "FAIL admin2 HTTP $admin_code" >&2; exit 1; }

unset token
echo "PASS login=$login_code entries=$entries_code rebuild=$rebuild_code pages=$pages_code users=self-only users_filters=$users_filters_code anonymous=$anonymous_code admin2=$admin_code"
