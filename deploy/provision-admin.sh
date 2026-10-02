#!/bin/sh
set -eu

: "${LITTLELIFE_ROOT:=/mnt/mmcblk0p6/littlelife}"
: "${LITTLELIFE_ADMIN_USER:=littlelife}"
: "${LITTLELIFE_ADMIN_PASSWORD_FILE:=$LITTLELIFE_ROOT/secrets/admin-password.txt}"

account="$LITTLELIFE_ROOT/runtime/grav-config/www/user/accounts/$LITTLELIFE_ADMIN_USER.yaml"
[ ! -e "$account" ] || { echo "Administrator already exists: $LITTLELIFE_ADMIN_USER"; exit 0; }
[ -r "$LITTLELIFE_ADMIN_PASSWORD_FILE" ] || { echo "ERROR: password file is unreadable: $LITTLELIFE_ADMIN_PASSWORD_FILE" >&2; exit 70; }
mode=$(LC_ALL=C ls -ld "$LITTLELIFE_ADMIN_PASSWORD_FILE" 2>/dev/null | awk '{print $1}')
[ "$mode" = -rw------- ] || { echo "ERROR: password file must have mode 0600" >&2; exit 71; }

password=$(sed -n '1p' "$LITTLELIFE_ADMIN_PASSWORD_FILE")
[ "${#password}" -ge 16 ] || { echo "ERROR: password must contain at least 16 characters" >&2; exit 72; }

docker exec -w /app/www/public littlelife-grav php bin/plugin login new-user \
  --user="$LITTLELIFE_ADMIN_USER" \
  --password="$password" \
  --email=littlelife@localhost.invalid \
  --language=zh-Hans \
  --permissions=s \
  --fullname='LittleLife Administrator' \
  --title='Archive Administrator' \
  --state=enabled \
  --no-interaction
unset password
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
$account["language"] = "zh-Hans";
$account["admin_next"] = [
    "preferences" => ["adminLanguage" => "zh-Hans"],
];
if (!yaml_emit_file($path, $account, YAML_UTF8_ENCODING, YAML_LN_BREAK)) {
    fwrite(STDERR, "Unable to write restricted account\n"); exit(1);
}
' "$LITTLELIFE_ADMIN_USER"
chown 1000:1000 "$account"
chmod 600 "$account"
echo "Created Admin2 account: $LITTLELIFE_ADMIN_USER"
