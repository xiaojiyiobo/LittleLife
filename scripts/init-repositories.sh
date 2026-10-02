#!/bin/sh
set -eu

: "${LITTLELIFE_ROOT:=/mnt/mmcblk0p6/littlelife}"
: "${LITTLELIFE_SECRETS_ENV:=$LITTLELIFE_ROOT/secrets/backup.env}"
[ -r "$LITTLELIFE_SECRETS_ENV" ] || { echo "ERROR: backup environment is unreadable" >&2; exit 80; }
# shellcheck disable=SC1090
. "$LITTLELIFE_SECRETS_ENV"
[ -z "${RCLONE_CONFIG:-}" ] || export RCLONE_CONFIG
PATH="$LITTLELIFE_ROOT/bin:$PATH"
export PATH

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
EXPECTED_MOUNT=${EXPECTED_MOUNT:-/mnt/mmcblk0p6} LITTLELIFE_ROOT="$LITTLELIFE_ROOT" \
  "$SCRIPT_DIR/preflight-mount.sh"
command -v restic >/dev/null 2>&1 || { echo "ERROR: restic is not installed" >&2; exit 81; }
command -v rclone >/dev/null 2>&1 || { echo "ERROR: rclone is not installed" >&2; exit 82; }

for label in A B; do
  eval "repository=\${RESTIC_REPOSITORY_$label:-}"
  eval "password_file=\${RESTIC_PASSWORD_FILE_$label:-}"
  if [ "$label" = B ] && [ -z "$repository" ] && [ -z "$password_file" ]; then
    echo "Repository B is not configured; running single-repository mode"
    continue
  fi
  [ -n "$repository" ] && [ -r "$password_file" ] || { echo "ERROR: repository $label secrets are incomplete" >&2; exit 83; }
  if RESTIC_REPOSITORY="$repository" RESTIC_PASSWORD_FILE="$password_file" restic snapshots >/dev/null 2>&1; then
    echo "Repository $label already initialized"
  else
    echo "Initializing repository $label"
    RESTIC_REPOSITORY="$repository" RESTIC_PASSWORD_FILE="$password_file" restic init
  fi
done
