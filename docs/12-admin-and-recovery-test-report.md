# Admin and recovery acceptance report

Date: 2026-10-02

Target: S20M / ImmortalWRT aarch64

Release under test: `0.2.0-dev`; exact commit is recorded in the release manifest and
target `deploy/DEPLOYED_COMMIT`.

## Administration acceptance

- Admin2 `/admin2`: HTTP 200 on the target-only LAN address.
- Anonymous archive API request: HTTP 401.
- Administrator login and JWT validation across requests: passed.
- Administrator ACL reduced to `api.access` plus LittleLife read/write only; no
  `api.super`, Pages, user-list, plugin or configuration write grant remains.
- Least-privilege API acceptance: LittleLife list/rebuild HTTP 200; generic Pages and
  user-filter endpoints HTTP 403; the generic Users endpoint returned only the signed-in
  account as designed by the upstream API plugin.
- LittleLife sidebar definition and custom page script: passed.
- Fictional record create and edit: passed.
- Fictional PNG upload: passed; original stored append-only and linked from Markdown.
- SHA-256 manifest regenerated and verified: two media files passed.
- Derived pages rebuilt and new story returned HTTP 200.
- Timeline year/month/tag/milestone filters rendered and executed in the LAN browser;
  tag filtering changed the visible count from 2/2 to 1/2 and reset restored 2/2.
- Open-format ZIP export generated: passed.
- Direct derived Markdown access: HTTP 403.

The acceptance record and image are explicitly fictional and may remain as examples
until real-data import is approved.

## Recovery acceptance

Official ARM64 tools were placed below the data disk, not `/overlay`:

- Restic 0.19.1, checksum verified against the official release `SHA256SUMS`.
- rclone 1.75.1, checksum verified against the official download `SHA256SUMS`.

Two temporary local Restic repositories were initialized solely to exercise the code.
Both accepted an independent backup, both passed `restic check`, and both restored into
separate new directories. Each restored archive contained two Markdown records and both
original-media SHA-256 checks passed.

On 2026-10-02 the owner accepted Google Drive as the single initial offsite repository.
The scripts were retested in repository-A-only mode against the local acceptance
repository: backup succeeded, ordinary `restic check` succeeded, a 5% data-pack read
reported no errors, and the generated cron block contained only repository A jobs.
Repository B remains optional and can be enabled later without changing the archive.

The seven pinned Grav plugins were also captured in a 10 MiB SHA-256-protected offline
bundle. A fresh Grav container with networking disabled installed and verified every
locked plugin version from that bundle; the disposable container was then removed.

The final acceptance snapshots also contained `deploy/compose.yaml`, the deployed Git
commit marker, custom application code, non-secret configuration, scripts and root
version/checksum manifests. Both repositories were restored again into fresh directories;
the required deployment files were present, secrets were absent, and both restored media
manifests passed in place.

A clean-host exercise then copied restored repository A into Windows `99_Sandbox`, used
Ubuntu 22.04 WSL2 on linux/amd64 to validate the two records, verify both media hashes
and regenerate all derived pages, initialized a new Grav runtime without old container
layers, installed the pinned plugins, provisioned a new least-privilege recovery account
and started an isolated container on `127.0.0.1:18081`. Home, timeline and Admin2 returned
HTTP 200, timeline filters were present, anonymous archive API returned 401, and the
container was healthy with zero restarts. The exercise took approximately seven minutes
after the restored tree was available; its temporary container and network were removed.

Pinned plugin versions verified on both the production and recovery paths are Login
3.9.12, API 1.0.44, Admin2 2.1.27, Form 9.1.32, Email 5.3.0, Shortcode Core 6.2.6 and
Flex Objects 1.4.16.

The owner accepted one Google Drive repository as the initial offsite design. Production
scheduling remains intentionally inactive only until its dedicated OAuth client,
repository path and Restic password have been installed and the first cloud restore has
passed.

## Runtime and isolation

- Container: healthy, zero restarts after final test restart, approximately 41 MiB RAM.
- Bind: exactly the configured LAN IPv4 on port 8080; the WAN-side address remained closed.
- Existing unrelated containers remained running.
- `/overlay`: about 37.4 MiB free; project tools and data remained on mmcblk0p6.
- LAN firewall rule remained scoped to the LittleLife Docker bridge TCP/80.
- VPS, FRP and public DNS/TLS were unchanged.

## Rollback

The pre-change target snapshot is
`/mnt/mmcblk0p6/littlelife/rollback/20261002-admin-0b3dd0c`; backup-tool files have a
second snapshot at `/mnt/mmcblk0p6/littlelife/rollback/20261002-backup-tools`. Account
permission changes create timestamped `*-account-permissions` snapshots before writing.
The backup-content expansion has its own snapshot at
`/mnt/mmcblk0p6/littlelife/rollback/20261002-backup-deploy-files`.
Canonical data must never be deleted during rollback.
