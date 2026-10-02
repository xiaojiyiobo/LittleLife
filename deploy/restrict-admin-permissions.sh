#!/bin/sh
set -eu
umask 077

: "${LITTLELIFE_ROOT:=/mnt/mmcblk0p6/littlelife}"
: "${LITTLELIFE_ADMIN_USER:=littlelife}"

account="$LITTLELIFE_ROOT/runtime/grav-config/www/user/accounts/$LITTLELIFE_ADMIN_USER.yaml"
[ -f "$account" ] || { echo "ERROR: administrator account not found: $account" >&2; exit 70; }

stamp=$(date -u +%Y%m%dT%H%M%SZ)
backup="$LITTLELIFE_ROOT/rollback/$stamp-account-permissions"
mkdir "$backup"
cp -p "$account" "$backup/$LITTLELIFE_ADMIN_USER.yaml"

docker exec -w /app/www/public littlelife-grav php -r '
$path = "/config/www/user/accounts/" . $argv[1] . ".yaml";
$account = yaml_parse_file($path);
if (!is_array($account)) { fwrite(STDERR, "Invalid account YAML\n"); exit(1); }
$account["access"] = [
    "api" => [
        "login" => true,
        "access" => true,
        "littlelife" => ["read" => true, "write" => true],
    ],
    "site" => ["login" => true],
];
if (!yaml_emit_file($path, $account, YAML_UTF8_ENCODING, YAML_LN_BREAK)) {
    fwrite(STDERR, "Unable to write restricted account\n"); exit(1);
}
' "$LITTLELIFE_ADMIN_USER"

chown 1000:1000 "$account"
chmod 600 "$account"
echo "Restricted account permissions; backup: $backup/$LITTLELIFE_ADMIN_USER.yaml"
