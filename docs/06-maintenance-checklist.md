# Maintenance checklist

## Weekly

- Review the latest successful backup time and snapshot ID for repository A and any
  configured optional repository B.
- Review Restic check results and capacity warnings.
- Confirm mount, container health, restart count, and `/overlay` free space.

## Monthly

- Sample original-media hashes and open random photo/video/audio files.
- Review the monthly 5% data-pack read result for every configured repository.
- Review storage, inode use, logs, temperatures, dependency updates, and certificate age.
- Test an individual-file restore into a new directory.
- If retention work is due, reserve day 8 for repository A or day 22 for repository B;
  prune only after the latest check and restore evidence has been reviewed.

## Quarterly

- Restore a recent snapshot from alternating repositories.
- Launch an isolated site or produce an offline export from the restored archive.
- Record elapsed time, missing knowledge, failures, and follow-up actions.

## Yearly

- Verify the full original-media manifest.
- Perform the clean-host disaster recovery exercise.
- Verify both offline credential packs and account-recovery paths.
- Review file-format readability, permissions, public exposure, and provider independence.

Never run unattended application/image upgrades. Stage, back up, test, record versions,
and keep a rollback route.

For a Google account change, follow the parallel-repository migration in
`04-backup-recovery-plan.md`; never replace the working account token before a restored
copy from the replacement account has passed validation.
