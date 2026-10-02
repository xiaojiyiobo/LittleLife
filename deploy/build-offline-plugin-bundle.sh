#!/bin/sh
set -eu

: "${LITTLELIFE_ROOT:=/mnt/mmcblk0p6/littlelife}"
lock="$LITTLELIFE_ROOT/config/grav-plugins.lock"
[ -r "$lock" ] || { echo "ERROR: plugin version lock is unreadable: $lock" >&2; exit 90; }
# shellcheck disable=SC1090
. "$lock"

packages="email:$EMAIL_VERSION form:$FORM_VERSION shortcode-core:$SHORTCODE_CORE_VERSION flex-objects:$FLEX_OBJECTS_VERSION login:$LOGIN_VERSION api:$API_VERSION admin2:$ADMIN2_VERSION"
plugin_root="$LITTLELIFE_ROOT/runtime/grav-config/www/user/plugins"
output_dir="$LITTLELIFE_ROOT/app/offline"
bundle="$output_dir/grav-plugins.tar.gz"
checksum="$bundle.sha256"

docker inspect littlelife-grav >/dev/null 2>&1 || {
  echo "ERROR: littlelife-grav is not running" >&2
  exit 91
}
[ -d "$plugin_root" ] || { echo "ERROR: runtime plugin directory is missing" >&2; exit 92; }

set --
for package in $packages; do
  name=${package%%:*}
  expected=${package#*:}
  actual=$(docker exec littlelife-grav php -r '
$path = "/config/www/user/plugins/" . $argv[1] . "/blueprints.yaml";
$plugin = is_file($path) ? yaml_parse_file($path) : null;
echo is_array($plugin) ? ($plugin["version"] ?? "") : "";
' "$name")
  [ "$actual" = "$expected" ] || {
    echo "ERROR: $name version is $actual, expected $expected" >&2
    exit 93
  }
  set -- "$@" "$name"
done

mkdir -p "$output_dir"
temporary="$output_dir/.grav-plugins.tar.gz.$$"
trap 'rm -f "$temporary"' EXIT HUP INT TERM
tar -C "$plugin_root" -czf "$temporary" "$@"
mv "$temporary" "$bundle"
trap - EXIT HUP INT TERM
(cd "$output_dir" && sha256sum "$(basename "$bundle")" >"$(basename "$checksum")")
chmod 0644 "$bundle" "$checksum"
echo "Created verified offline plugin bundle: $bundle"
