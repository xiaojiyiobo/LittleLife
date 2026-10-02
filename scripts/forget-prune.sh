#!/bin/sh
set -eu

usage() {
  echo "Usage: ALLOW_PRUNE=yes $0 A|B" >&2
  exit 40
}

[ "$#" -eq 1 ] || usage
[ "${ALLOW_PRUNE:-no}" = yes ] || { echo "ERROR: set ALLOW_PRUNE=yes after reviewing repository health" >&2; exit 41; }

label=$1
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
command -v restic >/dev/null 2>&1 || { echo "ERROR: restic is not installed" >&2; exit 44; }
command -v rclone >/dev/null 2>&1 || { echo "ERROR: rclone is not installed" >&2; exit 45; }

eval "repository=\${RESTIC_REPOSITORY_$label:-}"
eval "password_file=\${RESTIC_PASSWORD_FILE_$label:-}"
[ -n "$repository" ] && [ -n "$password_file" ] || { echo "ERROR: repository $label is not configured" >&2; exit 42; }

lock_dir="$LITTLELIFE_ROOT/backup/locks/prune-$label.lock"
mkdir -p "$LITTLELIFE_ROOT/backup/locks"
mkdir "$lock_dir" 2>/dev/null || { echo "ERROR: prune lock exists for repository $label" >&2; exit 43; }
trap 'rmdir "$lock_dir" 2>/dev/null || true' EXIT HUP INT TERM

echo "Checking repository $label before retention/prune"
RESTIC_REPOSITORY="$repository" RESTIC_PASSWORD_FILE="$password_file" restic check
RESTIC_REPOSITORY="$repository" RESTIC_PASSWORD_FILE="$password_file" \
  restic forget --prune \
    --keep-hourly 4 \
    --keep-daily 30 \
    --keep-weekly 12 \
    --keep-monthly 24 \
    --keep-yearly 18 \
    --tag littlelife

