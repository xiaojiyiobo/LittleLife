# Offline recovery pack checklist

Create two encrypted recovery packs and store them in different safe locations. Each
pack must contain:

- this repository release bundle and its SHA-256;
- `app/offline/grav-plugins.tar.gz` and its matching SHA-256 file;
- the architecture, directory mapping, backup/recovery plan and maintenance checklist;
- Restic repository A identifier, Google account-recovery instructions, and optional B
  details if a second provider is added;
- Restic password file A and optional B password file;
- `rclone.conf` and any provider-specific tokens required by it;
- the current LittleLife administrator credential or a documented reset procedure;
- VPS host/provider recovery details, SSH key recovery instructions, Nginx virtual host,
  FRP server/client configuration and future TLS renewal notes;
- exact commands for `restic snapshots`, `restic check`, `restore.sh`, media hash
  verification and clean deployment;
- the date and result of the most recent successful restore from each provider.

Do not keep both packs in the same room, device, cloud account or password-manager-only
failure domain. Never place their secrets in Git, the Docker image, ordinary logs or
the public website.

Once per year, decrypt and read both packs, verify the credentials, restore from one
repository to a clean staging directory, rebuild the site without old container layers,
and update this checklist with the result.

From the restored LittleLife root on a clean Linux host, rebuild disposable Grav pages
before starting the container:

```sh
python3 -m venv .recovery-venv
. .recovery-venv/bin/activate
pip install -r requirements-dev.txt
python scripts/archive_tool.py validate --data data
python scripts/archive_tool.py verify --data data
python scripts/archive_tool.py build-pages --data data --output derived/grav-pages
# Copy deploy/.env.example to deploy/.env and set the new host paths first.
sh deploy/start.sh
sh deploy/install-grav-plugins.sh
sh deploy/provision-admin.sh
```

The virtual environment is temporary build tooling and must not be copied into the
archive or release artifact.
