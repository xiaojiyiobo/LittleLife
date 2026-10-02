# Deployment templates

These files deploy the LittleLife browsing and administration layers. Run `start.sh` only from a complete,
verified bundle containing sibling `app`, `config`, `derived`, and `scripts`
directories.

On S20M, copy the non-secret settings from the bundle root `.env.example` to
`deploy/.env`. The expected defaults are:

- root: `/mnt/mmcblk0p6/littlelife`
- required mount/device/filesystem: `/mnt/mmcblk0p6`, `/dev/mmcblk0p6`, ext4
- HTTP default: `127.0.0.1:8080`
- resources: 1 CPU and 512 MiB RAM
- image: pinned LinuxServer Grav multi-architecture digest

`start.sh` performs the mount/path/filesystem preflight before creating directories or
starting a container. It then initializes an empty Grav `/config` with networking
disabled and starts the service on the configured address. Keep the default loopback
address unless a reviewed target-specific LAN address is required; never use `0.0.0.0`
on a router. It is compatible with the BusyBox tools observed on ImmortalWRT.

Stop the service with `stop.sh`. Stopping does not delete archive data, generated pages,
or Grav runtime files.

On a new runtime, run `install-grav-plugins.sh` immediately after the first start. It
installs and verifies the exact Login, API, Admin2 and dependency versions recorded in
`config/grav-plugins.lock`. A verified `app/offline/grav-plugins.tar.gz` is preferred;
the installer falls back to GPM only when the bundle is absent. Refresh the offline
bundle with `build-offline-plugin-bundle.sh` after a reviewed plugin upgrade. The
resulting runtime is then covered by normal upgrade/rollback controls.

After Google Drive repository A is configured in `secrets/backup.env`, run
`install-schedule.sh`. Repository B is optional and is scheduled only when both of its
values are present. The script installs 6-hour backups, separately timed weekly checks,
separately timed monthly 5% data-pack reads, and monthly media verification. Destructive
retention/prune remains a supervised command and is never installed in cron.

After the first start, place a strong generated password in
`secrets/admin-password.txt` with mode `0600`, then run `provision-admin.sh`. The
administrator signs in at `/admin2`; the dedicated **LittleLife 档案** page is the only
supported write interface. Do not edit archive content through Admin2's generic Pages
screen because those pages are disposable derivatives.

`provision-admin.sh` creates a least-privilege account limited to the LittleLife API.
For an account created by an older deployment, run `restrict-admin-permissions.sh`;
the script makes a timestamped copy of the account YAML below `rollback/` before it
replaces the ACL.
