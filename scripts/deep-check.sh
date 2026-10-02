#!/bin/sh
set -eu

usage() {
  echo "Usage: $0 A|B" >&2
  exit 93
}

[ "$#" -eq 1 ] || usage
label=$1
case "$label" in A|B) ;; *) usage ;; esac

: "${LITTLELIFE_ROOT:=/mnt/mmcblk0p6/littlelife}"
: "${LITTLELIFE_SECRETS_ENV:=$LITTLELIFE_ROOT/secrets/backup.env}"
: "${RESTIC_READ_DATA_SUBSET:=5%}"
[ -r "$LITTLELIFE_SECRETS_ENV" ] || { echo "ERROR: backup environment is unreadable" >&2; exit 94; }
# shellcheck disable=SC1090
. "$LITTLELIFE_SECRETS_ENV"
[ -z "${RCLONE_CONFIG:-}" ] || export RCLONE_CONFIG
PATH="$LITTLELIFE_ROOT/bin:$PATH"
export PATH

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
EXPECTED_MOUNT=${EXPECTED_MOUNT:-/mnt/mmcblk0p6} LITTLELIFE_ROOT="$LITTLELIFE_ROOT" \
  "$SCRIPT_DIR/preflight-mount.sh"
command -v restic >/dev/null 2>&1 || { echo "ERROR: restic is not installed" >&2; exit 95; }
command -v rclone >/dev/null 2>&1 || { echo "ERROR: rclone is not installed" >&2; exit 96; }

eval "repository=\${RESTIC_REPOSITORY_$label:-}"
eval "password_file=\${RESTIC_PASSWORD_FILE_$label:-}"
[ -n "$repository" ] && [ -n "$password_file" ] || { echo "ERROR: repository $label is not configured" >&2; exit 97; }

lock_dir="$LITTLELIFE_ROOT/backup/locks/deep-check-$label.lock"
mkdir -p "$LITTLELIFE_ROOT/backup/locks"
mkdir "$lock_dir" 2>/dev/null || { echo "ERROR: deep-check lock exists for repository $label" >&2; exit 98; }
trap 'rmdir "$lock_dir" 2>/dev/null || true' EXIT HUP INT TERM

echo "Reading $RESTIC_READ_DATA_SUBSET of repository $label data packs"
RESTIC_REPOSITORY="$repository" RESTIC_PASSWORD_FILE="$password_file" \
  restic check --read-data-subset="$RESTIC_READ_DATA_SUBSET"
