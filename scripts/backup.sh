#!/bin/sh
set -u

: "${LITTLELIFE_ROOT:=/mnt/mmcblk0p6/littlelife}"
: "${LITTLELIFE_SECRETS_ENV:=$LITTLELIFE_ROOT/secrets/backup.env}"

if [ ! -r "$LITTLELIFE_SECRETS_ENV" ]; then
  echo "ERROR: backup secret environment is unreadable: $LITTLELIFE_SECRETS_ENV" >&2
  exit 30
fi
secret_mode=$(LC_ALL=C ls -ld "$LITTLELIFE_SECRETS_ENV" 2>/dev/null | awk '{print $1}')
case "$secret_mode" in
  -rw-------|-r--------) ;;
  *) echo "ERROR: backup secret environment must have mode 0600 or 0400" >&2; exit 36 ;;
esac

# shellcheck disable=SC1090
. "$LITTLELIFE_SECRETS_ENV"
[ -z "${RCLONE_CONFIG:-}" ] || export RCLONE_CONFIG
PATH="$LITTLELIFE_ROOT/bin:$PATH"
export PATH

for variable in RESTIC_REPOSITORY_A RESTIC_PASSWORD_FILE_A; do
  eval "value=\${$variable:-}"
  if [ -z "$value" ]; then
    echo "ERROR: required secret variable is unset: $variable" >&2
    exit 31
  fi
done
if { [ -n "${RESTIC_REPOSITORY_B:-}" ] && [ -z "${RESTIC_PASSWORD_FILE_B:-}" ]; } ||
   { [ -z "${RESTIC_REPOSITORY_B:-}" ] && [ -n "${RESTIC_PASSWORD_FILE_B:-}" ]; }; then
  echo "ERROR: optional repository B must define both repository and password file" >&2
  exit 31
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
EXPECTED_MOUNT=${EXPECTED_MOUNT:-/mnt/mmcblk0p6} LITTLELIFE_ROOT="$LITTLELIFE_ROOT" \
  "$SCRIPT_DIR/preflight-mount.sh" || exit $?

command -v restic >/dev/null 2>&1 || { echo "ERROR: restic is not installed" >&2; exit 32; }
command -v rclone >/dev/null 2>&1 || { echo "ERROR: rclone is not installed" >&2; exit 33; }

lock_dir="$LITTLELIFE_ROOT/backup/locks/backup.lock"
log_dir="$LITTLELIFE_ROOT/backup/logs"
mkdir -p "$LITTLELIFE_ROOT/backup/locks" "$log_dir"
if ! mkdir "$lock_dir" 2>/dev/null; then
  echo "ERROR: another backup appears to be running: $lock_dir" >&2
  exit 34
fi
trap 'rmdir "$lock_dir" 2>/dev/null || true' EXIT HUP INT TERM

timestamp=$(date -u +%Y%m%dT%H%M%SZ)

run_backup() {
  label=$1
  repository=$2
  password_file=$3
  log_file="$log_dir/${timestamp}-repository-${label}.log"

  set -- \
    "$LITTLELIFE_ROOT/data" \
    "$LITTLELIFE_ROOT/app" \
    "$LITTLELIFE_ROOT/config" \
    "$LITTLELIFE_ROOT/data-schema" \
    "$LITTLELIFE_ROOT/docs" \
    "$LITTLELIFE_ROOT/scripts" \
    "$LITTLELIFE_ROOT/deploy" \
    "$LITTLELIFE_ROOT/tests" \
    "$LITTLELIFE_ROOT/examples"
  for root_file in VERSION README.md README.zh-CN.md LICENSE DEPLOYMENT.txt SHA256SUMS requirements-dev.txt .env.example .gitattributes .gitignore; do
    [ ! -f "$LITTLELIFE_ROOT/$root_file" ] || set -- "$@" "$LITTLELIFE_ROOT/$root_file"
  done

  echo "Starting repository $label backup at $timestamp" | tee -a "$log_file"
  RESTIC_REPOSITORY="$repository" RESTIC_PASSWORD_FILE="$password_file" \
    restic backup \
      "$@" \
      --exclude "$LITTLELIFE_ROOT/secrets" \
      --exclude "$LITTLELIFE_ROOT/runtime" \
      --exclude "$LITTLELIFE_ROOT/derived" \
      --exclude "$LITTLELIFE_ROOT/backup" \
      --tag littlelife --tag "repository-$label" \
      --json >>"$log_file" 2>&1
  status=$?
  if [ "$status" -eq 0 ]; then
    echo "Repository $label backup succeeded" | tee -a "$log_file"
  else
    echo "Repository $label backup FAILED with status $status" | tee -a "$log_file" >&2
  fi
  return "$status"
}

status_a=0
run_backup A "$RESTIC_REPOSITORY_A" "$RESTIC_PASSWORD_FILE_A" || status_a=$?
status_b=0
if [ -n "${RESTIC_REPOSITORY_B:-}" ]; then
  run_backup B "$RESTIC_REPOSITORY_B" "$RESTIC_PASSWORD_FILE_B" || status_b=$?
else
  echo "Repository B is not configured; running single-repository mode"
fi

if [ "$status_a" -ne 0 ] || [ "$status_b" -ne 0 ]; then
  exit 35
fi

