# Public quick start

This guide starts a fictional LittleLife demo on a Linux host. Do not use personal
family data until you have reviewed access control and completed a backup/restore test.

## Requirements

- A Linux ARM64 or amd64 host
- Docker Engine with the Compose plugin
- Python 3.10 or newer
- A dedicated ext4 (or similarly durable Linux) data filesystem with sufficient space
- Git and outbound HTTPS for the initial clone, image pull and plugin installation

The commands below use `/mnt/data` as an example mounted filesystem. Replace its device
and filesystem values with facts from your host; do not copy them blindly.

## 1. Clone onto mounted storage

```sh
mountpoint -q /mnt/data
git clone https://github.com/xiaojiyiobo/LittleLife.git /mnt/data/littlelife
cd /mnt/data/littlelife
```

The start script refuses to run when the expected mount is missing or when the project
root escapes that mount.

## 2. Build the fictional demo archive

```sh
cp -a examples/archive/data ./data
python3 -m venv .venv
. .venv/bin/activate
python -m pip install -r requirements-dev.txt
python scripts/archive_tool.py validate --data data
python scripts/archive_tool.py verify --data data
python scripts/archive_tool.py build-pages --data data --output derived/grav-pages
```

Only `derived/grav-pages` is generated. The Markdown/YAML and original media under
`data/` remain the source of truth.

## 3. Configure the deployment

```sh
cp .env.example deploy/.env
```

Edit `deploy/.env` and set at least:

```dotenv
LITTLELIFE_ROOT=/mnt/data/littlelife
LITTLELIFE_BIND_ADDRESS=127.0.0.1
EXPECTED_MOUNT=/mnt/data
EXPECTED_DEVICE=/dev/REPLACE_WITH_YOUR_DEVICE
EXPECTED_FILESYSTEM=ext4
TZ=REPLACE_WITH_YOUR_TIMEZONE
```

Keep the loopback bind when using a reverse proxy on the same host. For LAN-only use,
set a specific trusted LAN address after reviewing the host firewall. Do not expose the
administrator interface directly to the public Internet and do not use `0.0.0.0` on a
router.

## 4. Start Grav and install pinned plugins

```sh
chmod +x deploy/*.sh scripts/*.sh scripts/archive_tool.py
./deploy/start.sh
./deploy/install-grav-plugins.sh
```

The first start creates disposable Grav runtime files without exposing a bootstrap
port. Plugin versions are verified against `config/grav-plugins.lock`.

## 5. Provision the least-privilege administrator

```sh
mkdir -p secrets
chmod 700 secrets
umask 077
openssl rand -base64 36 > secrets/admin-password.txt
chmod 600 secrets/admin-password.txt
./deploy/provision-admin.sh
```

The default username is `littlelife`. Sign in at `/admin2`, then use **LittleLife 档案**
for archive writes. Generic Grav Pages are generated presentation files, not the
canonical archive.

## 6. Verify the demo

```sh
python -m unittest discover -s tests -v
curl --fail http://127.0.0.1:8080/
curl --fail http://127.0.0.1:8080/timeline
```

If you configured a specific LAN address, substitute it in the URLs. Before adding
personal data, configure Restic/rclone using `config/backup.env.example`, run a backup,
restore it into a new directory with `scripts/restore.sh`, and verify both
`SHA256SUMS` and `data/manifests/media-sha256.txt`.

## Updating and recovery

- Back up and verify a restore before upgrades.
- Never restore directly over the live archive.
- Keep credentials outside Git and the Restic snapshot.
- Treat `data/` as authoritative; `derived/` and `runtime/` are replaceable.
- Review [the maintenance checklist](06-maintenance-checklist.md) regularly.
