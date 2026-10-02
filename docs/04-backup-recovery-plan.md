# Backup and recovery plan

## Repositories

Repository A is the required Restic repository. The accepted initial provider is Google
Drive through rclone's native backend. Repository B remains supported but optional;
when added, it should use a different account and preferably a different provider.
Repository URLs, passwords, `rclone.conf`, API tokens, and account-recovery details
live only in the target `secrets/` directory and separately stored offline recovery
packs. The owner accepted the reduced redundancy of single-repository mode on
2026-10-02; local recovery media is still required.

Each repository snapshot contains canonical `data/`, custom `app/`, non-secret
`config/`, schemas, recovery documentation, `scripts/`, container/deployment files
under `deploy/`, tests, fictional recovery examples, Git policy files, and available
root version/checksum/dependency manifests. This makes the release `SHA256SUMS`
directly verifiable after a full restore. Runtime state, derived files, local backup
workspaces and all `secrets/` content are excluded.

## Schedule

- Every 6 hours: backup to A and, if configured, B independently.
- Weekly: `restic check` on A at Sunday 03:23; optional B runs at Sunday 05:23.
- Monthly: read 5% of repository A data packs on day 5 and optional B on day 19;
  sample original-media hashes on day 12. `RESTIC_READ_DATA_SUBSET` can raise the
  read percentage for a supervised maintenance run.
- Quarterly: restore from alternating repositories into a fresh staging directory.
- Yearly: full original-media verification and complete clean-host disaster exercise.

Retention target: 4 hourly, 30 daily, 12 weekly, 24 monthly, and at least 18 yearly
snapshots. `forget --prune` is never part of the normal backup command. It requires an
explicit repository selection and a successful health/restore review. A and B prune
windows must not overlap. The reserved manual windows are day 8 for A and day 22 for
B; they are deliberately absent from cron. Run `ALLOW_PRUNE=yes
scripts/forget-prune.sh A|B` only after reviewing the latest check and restore record.

## Recovery order

1. Stop writers and preserve the suspected damaged state.
2. Restore into a new staging directory; never overwrite the live archive directly.
3. Verify the archive contract and SHA-256 manifest.
4. Compare and promote only the required files for a small recovery, or rebuild the
   service from clean containers for a device recovery.
5. Record snapshot ID, hashes, operator, timestamps, reason, and validation results.

## Offline pack contents

- Repository identifiers and provider/account recovery instructions.
- Restic passwords and `rclone.conf` on encrypted media.
- Exact restore and verification commands.
- This runbook, the archive schema, and a known-good release bundle.
- VPS/FRP/TLS recovery notes stored separately from public source.

No backup is considered healthy until data has been restored and opened.

## Changing the Google account

The archive is not tied to one Google identity. To change accounts without creating a
backup gap:

1. Create a new rclone remote with the dedicated LittleLife OAuth client and authorize
   the replacement Google account.
2. Initialize a new Restic repository with a new repository password; do not point the
   new account at the old repository name unless ownership and access were deliberately
   transferred.
3. Run a full backup, `restic check`, a data-pack read check, and restore into a new
   staging directory. Open records and verify original-media hashes.
4. Update target-only `secrets/rclone.conf` and `RESTIC_REPOSITORY_A`, then reinstall
   the managed schedule and confirm the next scheduled backup succeeds.
5. Keep the old repository read-only until at least one later scheduled backup and one
   restore from the new account have passed. Deletion is a separate owner decision.

No application code, canonical record, media path or public Git repository changes are
required for this migration.

