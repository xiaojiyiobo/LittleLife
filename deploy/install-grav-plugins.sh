#!/bin/sh
set -eu

: "${LITTLELIFE_ROOT:=/mnt/mmcblk0p6/littlelife}"
lock="$LITTLELIFE_ROOT/config/grav-plugins.lock"
[ -r "$lock" ] || { echo "ERROR: plugin version lock is unreadable: $lock" >&2; exit 80; }
# shellcheck disable=SC1090
. "$lock"

packages="email:$EMAIL_VERSION form:$FORM_VERSION shortcode-core:$SHORTCODE_CORE_VERSION flex-objects:$FLEX_OBJECTS_VERSION login:$LOGIN_VERSION api:$API_VERSION admin2:$ADMIN2_VERSION"
offline_dir="$LITTLELIFE_ROOT/app/offline"
offline_bundle="$offline_dir/grav-plugins.tar.gz"
offline_checksum="$offline_bundle.sha256"

docker inspect littlelife-grav >/dev/null 2>&1 || {
  echo "ERROR: littlelife-grav is not running; start the container first" >&2
  exit 81
}

plugin_version() {
  docker exec littlelife-grav php -r '
$path = "/config/www/user/plugins/" . $argv[1] . "/blueprints.yaml";
$plugin = is_file($path) ? yaml_parse_file($path) : null;
echo is_array($plugin) ? ($plugin["version"] ?? "") : "";
' "$1"
}

missing=''
missing_names=''
for package in $packages; do
  name=${package%%:*}
  expected=${package#*:}
  actual=$(plugin_version "$name")
  if [ -z "$actual" ]; then
    missing="$missing $package"
    missing_names="$missing_names $name"
  elif [ "$actual" != "$expected" ]; then
    echo "ERROR: $name version is $actual, expected $expected; review before changing it" >&2
    exit 82
  fi
done

if [ -n "$missing" ]; then
  if [ -r "$offline_bundle" ] && [ -r "$offline_checksum" ]; then
    (cd "$offline_dir" && sha256sum -c "$(basename "$offline_checksum")")
    if tar -tzf "$offline_bundle" | awk '
      BEGIN {ok=1}
      /^\// || /(^|\/)\.\.($|\/)/ {ok=0}
      !/^(email|form|shortcode-core|flex-objects|login|api|admin2)(\/|$)/ {ok=0}
      END {exit ok ? 0 : 1}
    '; then :; else
      echo "ERROR: offline plugin bundle contains an unsafe or unexpected path" >&2
      exit 83
    fi
    plugin_root="$LITTLELIFE_ROOT/runtime/grav-config/www/user/plugins"
    # Word splitting is intentional: names come from the fixed package list above.
    # shellcheck disable=SC2086
    tar -xzf "$offline_bundle" -C "$plugin_root" $missing_names
    for name in $missing_names; do
      chown -R "${PUID:-1000}:${PGID:-1000}" "$plugin_root/$name"
    done
    echo "Installed missing pinned plugins from the verified offline bundle."
  else
    # Word splitting is intentional: package names and versions come from the fixed lock file.
    # shellcheck disable=SC2086
    set -- $missing
    docker exec -w /app/www/public littlelife-grav php bin/gpm install \
      --all-yes --no-interaction "$@"
  fi
else
  echo "All pinned Grav plugins are already installed."
fi

for package in $packages; do
  name=${package%%:*}
  expected=${package#*:}
  actual=$(plugin_version "$name")
  if [ "$actual" != "$expected" ]; then
    echo "ERROR: $name version is $actual, expected $expected" >&2
    exit 82
  fi
  echo "Verified Grav plugin: $name $actual"
done

docker exec -w /app/www/public littlelife-grav php bin/grav clearcache --no-interaction >/dev/null
echo "Pinned Grav plugins installed and verified."
