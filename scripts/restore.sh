#!/bin/sh
set -eu

usage() {
  echo "Usage: $0 A|B SNAPSHOT TARGET_DIRECTORY" >&2
  echo "Example: $0 A latest /mnt/mmcblk0p6/littlelife/backup/restores/2026-10-02" >&2
  exit 50
}

[ "$#" -eq 3 ] || usage
label=$1
snapshot=$2
target=$3
case "$label" in A|B) ;; *) usage ;; esac

: "${LITTLELIFE_ROOT:=/mnt/mmcblk0p6/littlelife}"
: "${LITTLELIFE_SECRETS_ENV:=$LITTLELIFE_ROOT/secrets/backup.env}"
# shellcheck disable=SC1090
. "$LITTLELIFE_SECRETS_ENV"
[ -z "${RCLONE_CONFIG:-}" ] || export RCLONE_CONFIG
PATH="$LITTLELIFE_ROOT/bin:$PATH"
export PATH

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
EXPECTED_MOUNT=${EXPECTED_MOUNT:-/mnt/mmcblk0p6} LITTLELIFE_ROOT="$LITTLELIFE_ROOT" \
  "$SCRIPT_DIR/preflight-mount.sh"
command -v restic >/dev/null 2>&1 || { echo "ERROR: restic is not installed" >&2; exit 54; }
command -v rclone >/dev/null 2>&1 || { echo "ERROR: rclone is not installed" >&2; exit 55; }

eval "repository=\${RESTIC_REPOSITORY_$label:-}"
eval "password_file=\${RESTIC_PASSWORD_FILE_$label:-}"
[ -n "$repository" ] && [ -n "$password_file" ] || { echo "ERROR: repository $label is not configured" >&2; exit 51; }

restore_base="$LITTLELIFE_ROOT/backup/restores"
mkdir -p "$restore_base"
restore_base=$(CDPATH= cd -- "$restore_base" && pwd -P)
case "$target" in
  "$restore_base"/*) ;;
  *) echo "ERROR: target must be below $restore_base" >&2; exit 52 ;;
esac
case "$target" in
  */../*|*/..|*/./*) echo "ERROR: target contains unsafe path segments" >&2; exit 52 ;;
esac
mkdir -p "$target"
resolved_target=$(CDPATH= cd -- "$target" && pwd -P)
case "$resolved_target" in "$restore_base"/*) ;; *) echo "ERROR: resolved target escapes $restore_base" >&2; exit 52;; esac
if [ -n "$(find "$resolved_target" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
  echo "ERROR: restore target is not empty: $resolved_target" >&2
  exit 53
fi

RESTIC_REPOSITORY="$repository" RESTIC_PASSWORD_FILE="$password_file" \
  restic restore "$snapshot" --target "$resolved_target"

echo "Restore completed in new directory: $resolved_target"
echo "Do not copy over live data until validation and hash verification pass."

