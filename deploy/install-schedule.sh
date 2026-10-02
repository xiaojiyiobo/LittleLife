#!/bin/sh
set -eu

: "${LITTLELIFE_ROOT:=/mnt/mmcblk0p6/littlelife}"
: "${CRONTAB_FILE:=/etc/crontabs/root}"

[ -x "$LITTLELIFE_ROOT/scripts/backup.sh" ] || { echo "ERROR: backup script is missing" >&2; exit 100; }
[ -x "$LITTLELIFE_ROOT/scripts/check-repositories.sh" ] || { echo "ERROR: repository check script is missing" >&2; exit 102; }
[ -x "$LITTLELIFE_ROOT/scripts/deep-check.sh" ] || { echo "ERROR: deep check script is missing" >&2; exit 103; }
[ -x "$LITTLELIFE_ROOT/scripts/verify-media.sh" ] || { echo "ERROR: media verification script is missing" >&2; exit 106; }
[ -x "$LITTLELIFE_ROOT/scripts/run-job.sh" ] || { echo "ERROR: job runner is missing" >&2; exit 107; }
[ -r "$LITTLELIFE_ROOT/secrets/backup.env" ] || { echo "ERROR: backup secrets are not configured" >&2; exit 101; }
# shellcheck disable=SC1090
. "$LITTLELIFE_ROOT/secrets/backup.env"
[ -n "${RESTIC_REPOSITORY_A:-}" ] && [ -n "${RESTIC_PASSWORD_FILE_A:-}" ] || {
  echo "ERROR: repository A is not configured" >&2
  exit 104
}
if { [ -n "${RESTIC_REPOSITORY_B:-}" ] && [ -z "${RESTIC_PASSWORD_FILE_B:-}" ]; } ||
   { [ -z "${RESTIC_REPOSITORY_B:-}" ] && [ -n "${RESTIC_PASSWORD_FILE_B:-}" ]; }; then
  echo "ERROR: optional repository B is only partially configured" >&2
  exit 105
fi

begin='# BEGIN LITTLELIFE MANAGED'
end='# END LITTLELIFE MANAGED'
backup="$CRONTAB_FILE.littlelife-before-$(date -u +%Y%m%dT%H%M%SZ)"
cp "$CRONTAB_FILE" "$backup"

temporary="$LITTLELIFE_ROOT/backup/crontab.new"
awk -v begin="$begin" -v end="$end" '
  $0 == begin {skip=1; next}
  $0 == end {skip=0; next}
  !skip {print}
' "$CRONTAB_FILE" >"$temporary"
cat >>"$temporary" <<EOF
$begin
17 */6 * * * $LITTLELIFE_ROOT/scripts/run-job.sh backup $LITTLELIFE_ROOT/scripts/backup.sh
23 3 * * 0 $LITTLELIFE_ROOT/scripts/run-job.sh repository-check-a $LITTLELIFE_ROOT/scripts/check-repositories.sh A
37 2 5 * * $LITTLELIFE_ROOT/scripts/run-job.sh deep-check-a $LITTLELIFE_ROOT/scripts/deep-check.sh A
41 4 12 * * $LITTLELIFE_ROOT/scripts/run-job.sh media-verify $LITTLELIFE_ROOT/scripts/verify-media.sh
EOF
if [ -n "${RESTIC_REPOSITORY_B:-}" ]; then
  cat >>"$temporary" <<EOF
23 5 * * 0 $LITTLELIFE_ROOT/scripts/run-job.sh repository-check-b $LITTLELIFE_ROOT/scripts/check-repositories.sh B
37 2 19 * * $LITTLELIFE_ROOT/scripts/run-job.sh deep-check-b $LITTLELIFE_ROOT/scripts/deep-check.sh B
EOF
fi
echo "$end" >>"$temporary"
cat "$temporary" >"$CRONTAB_FILE"
rm -f "$temporary"
if [ "${SKIP_CRON_RESTART:-no}" != yes ]; then
  /etc/init.d/cron restart
fi
echo "Installed LittleLife schedule; previous crontab: $backup"
