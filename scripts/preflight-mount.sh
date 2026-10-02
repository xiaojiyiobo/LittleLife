#!/bin/sh
set -eu

: "${EXPECTED_MOUNT:=/mnt/mmcblk0p6}"
: "${LITTLELIFE_ROOT:=$EXPECTED_MOUNT/littlelife}"
: "${EXPECTED_DEVICE:=}"
: "${EXPECTED_FILESYSTEM:=}"

if [ ! -d "$EXPECTED_MOUNT" ]; then
  echo "ERROR: expected mount directory does not exist: $EXPECTED_MOUNT" >&2
  exit 20
fi

if command -v mountpoint >/dev/null 2>&1; then
  if ! mountpoint -q "$EXPECTED_MOUNT"; then
    echo "ERROR: $EXPECTED_MOUNT is not a mount point; refusing to start" >&2
    exit 21
  fi
elif ! awk -v expected="$EXPECTED_MOUNT" '$2 == expected { found=1 } END { exit !found }' /proc/mounts; then
  echo "ERROR: $EXPECTED_MOUNT is not present in /proc/mounts; refusing to start" >&2
  exit 21
fi

if ! command -v readlink >/dev/null 2>&1; then
  echo "ERROR: readlink is required for path confinement checks" >&2
  exit 28
fi

resolved_mount=$(readlink -f "$EXPECTED_MOUNT")
resolved_root=$(readlink -f "$LITTLELIFE_ROOT")
case "$resolved_mount" in
  /|/overlay)
    echo "ERROR: refusing unsafe mount target: $resolved_mount" >&2
    exit 29
    ;;
esac
case "$resolved_root" in
  "$resolved_mount"/*) ;;
  *)
    echo "ERROR: LITTLELIFE_ROOT is outside the verified mount: $resolved_root" >&2
    exit 22
    ;;
esac

device=$(df -PT "$resolved_mount" | awk 'NR == 2 { print $1 }')
filesystem=$(df -PT "$resolved_mount" | awk 'NR == 2 { print $2 }')
case "$filesystem" in
  overlay|overlayfs|tmpfs|rootfs)
    echo "ERROR: unsafe filesystem for archive data: $filesystem" >&2
    exit 24
    ;;
esac

if [ -n "$EXPECTED_DEVICE" ] && [ "$device" != "$EXPECTED_DEVICE" ]; then
  echo "ERROR: mount device is $device, expected $EXPECTED_DEVICE" >&2
  exit 30
fi

if [ -n "$EXPECTED_FILESYSTEM" ] && [ "$filesystem" != "$EXPECTED_FILESYSTEM" ]; then
  echo "ERROR: mount filesystem is $filesystem, expected $EXPECTED_FILESYSTEM" >&2
  exit 31
fi

echo "Mount preflight passed: root=$resolved_root device=$device filesystem=$filesystem"

