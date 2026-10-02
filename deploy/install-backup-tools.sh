#!/bin/sh
set -eu

: "${LITTLELIFE_ROOT:=/mnt/mmcblk0p6/littlelife}"
: "${RESTIC_VERSION:=0.19.1}"
: "${RCLONE_VERSION:=1.75.1}"

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
EXPECTED_MOUNT=${EXPECTED_MOUNT:-/mnt/mmcblk0p6} LITTLELIFE_ROOT="$LITTLELIFE_ROOT" \
  "$PROJECT_DIR/scripts/preflight-mount.sh"

download="$LITTLELIFE_ROOT/backup/downloads"
bin="$LITTLELIFE_ROOT/bin"
mkdir -p "$download" "$bin"
chmod 0750 "$download" "$bin"

restic_file="restic_${RESTIC_VERSION}_linux_arm64.bz2"
restic_base="https://github.com/restic/restic/releases/download/v${RESTIC_VERSION}"
curl -fL --retry 3 --proto '=https' --tlsv1.2 -o "$download/$restic_file" "$restic_base/$restic_file"
curl -fL --retry 3 --proto '=https' --tlsv1.2 -o "$download/restic-SHA256SUMS" "$restic_base/SHA256SUMS"
(cd "$download" && grep "  $restic_file\$" restic-SHA256SUMS | sha256sum -c -)
bzip2 -dc "$download/$restic_file" >"$bin/restic.new"
chmod 0755 "$bin/restic.new"
mv "$bin/restic.new" "$bin/restic"

rclone_file="rclone-v${RCLONE_VERSION}-linux-arm64.zip"
rclone_base="https://downloads.rclone.org/v${RCLONE_VERSION}"
curl -fL --retry 3 --proto '=https' --tlsv1.2 -o "$download/$rclone_file" "$rclone_base/$rclone_file"
curl -fL --retry 3 --proto '=https' --tlsv1.2 -o "$download/rclone-SHA256SUMS" "$rclone_base/SHA256SUMS"
(cd "$download" && grep "  $rclone_file\$" rclone-SHA256SUMS | sha256sum -c -)
unzip -p "$download/$rclone_file" "*/rclone" >"$bin/rclone.new"
chmod 0755 "$bin/rclone.new"
mv "$bin/rclone.new" "$bin/rclone"

{
  "$bin/restic" version
  "$bin/rclone" version | sed -n '1,6p'
} >"$bin/VERSIONS"
chmod 0644 "$bin/VERSIONS"
cat "$bin/VERSIONS"
