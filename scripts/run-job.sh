#!/bin/sh
set -u

[ "$#" -ge 2 ] || { echo "Usage: $0 JOB_NAME COMMAND [ARG...]" >&2; exit 110; }
job=$1
shift
case "$job" in *[!a-zA-Z0-9_-]*|'') echo "ERROR: invalid job name" >&2; exit 111;; esac

: "${LITTLELIFE_ROOT:=/mnt/mmcblk0p6/littlelife}"
timestamp=$(date -u +%Y%m%dT%H%M%SZ)
log_dir="$LITTLELIFE_ROOT/backup/logs"
status_dir="$LITTLELIFE_ROOT/backup/status"
mkdir -p "$log_dir" "$status_dir"
log="$log_dir/${timestamp}-${job}.log"

started=$(date -u +%Y-%m-%dT%H:%M:%SZ)
"$@" >"$log" 2>&1
result=$?
finished=$(date -u +%Y-%m-%dT%H:%M:%SZ)
temporary="$status_dir/.${job}.tmp.$$"
{
  echo "job=$job"
  echo "started_at=$started"
  echo "finished_at=$finished"
  echo "exit_code=$result"
  echo "log=$log"
} >"$temporary"
mv "$temporary" "$status_dir/$job.status"

if [ "$result" -eq 0 ]; then
  logger -t littlelife "$job succeeded; log=$log" 2>/dev/null || true
else
  logger -p user.err -t littlelife "$job FAILED exit=$result; log=$log" 2>/dev/null || true
fi
exit "$result"
