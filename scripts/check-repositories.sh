#!/bin/sh
set -u

usage() {
  echo "Usage: $0 [A|B]" >&2
  exit 89
}

[ "$#" -le 1 ] || usage
case "${1:-}" in ''|A|B) ;; *) usage ;; esac

: "${LITTLELIFE_ROOT:=/mnt/mmcblk0p6/littlelife}"
: "${LITTLELIFE_SECRETS_ENV:=$LITTLELIFE_ROOT/secrets/backup.env}"
[ -r "$LITTLELIFE_SECRETS_ENV" ] || { echo "ERROR: backup environment is unreadable" >&2; exit 90; }
# shellcheck disable=SC1090
. "$LITTLELIFE_SECRETS_ENV"
[ -z "${RCLONE_CONFIG:-}" ] || export RCLONE_CONFIG
PATH="$LITTLELIFE_ROOT/bin:$PATH"
export PATH

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
EXPECTED_MOUNT=${EXPECTED_MOUNT:-/mnt/mmcblk0p6} LITTLELIFE_ROOT="$LITTLELIFE_ROOT" \
  "$SCRIPT_DIR/preflight-mount.sh" || exit $?

timestamp=$(date -u +%Y%m%dT%H%M%SZ)
log_dir="$LITTLELIFE_ROOT/backup/logs"
mkdir -p "$log_dir"
result=0
labels=${1:-"A B"}
for label in $labels; do
  eval "repository=\${RESTIC_REPOSITORY_$label:-}"
  eval "password_file=\${RESTIC_PASSWORD_FILE_$label:-}"
  if [ -z "${1:-}" ] && [ "$label" = B ] && [ -z "$repository" ] && [ -z "$password_file" ]; then
    echo "Repository B is not configured; running single-repository mode"
    continue
  fi
  if [ -z "$repository" ] || [ -z "$password_file" ]; then
    echo "ERROR: repository $label is not configured" >&2
    result=92
    continue
  fi
  log="$log_dir/${timestamp}-check-$label.log"
  if RESTIC_REPOSITORY="$repository" RESTIC_PASSWORD_FILE="$password_file" restic check >"$log" 2>&1; then
    echo "Repository $label check succeeded"
  else
    echo "ERROR: repository $label check failed; see $log" >&2
    result=91
  fi
done
exit "$result"
