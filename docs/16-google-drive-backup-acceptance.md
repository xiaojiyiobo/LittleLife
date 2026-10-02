# Google Drive backup acceptance

Acceptance date: 2026-10-02 (Asia/Hong_Kong)

## Result

The production Google Drive backup path passed end-to-end acceptance on the native
ImmortalWRT ARM64 target. The dedicated OAuth desktop client uses the limited
`drive.file` scope. Its token, client secret, Restic password and repository settings
exist only in the target's mode-`0600` secret files and are excluded from Git and
Restic snapshots.

The owner selected one Google Drive repository for the initial deployment and accepted
the reduced provider redundancy. Repository B remains supported by the scripts but is
not configured.

## Evidence

| Check | Result |
| --- | --- |
| Deployed operational commit | `b1d070693b509d6ba6b2da0c3f6238cf683aa755` |
| Release artifact SHA-256 | `2fe2fbd36a0182e8905bc47b20a077c8f605a435586543dbb43a807292f6e1ea` |
| Google Drive API access | Passed with dedicated client and `drive.file` scope |
| Initial and corrected cloud snapshots | Passed |
| `restic check` | Passed after each restore candidate |
| Fresh-directory restore | 147 files/directories; 102 files; 10.263 MiB |
| Full release `SHA256SUMS` | Passed |
| Original-media SHA-256 manifest | Passed |
| Offline Grav plugin bundle checksum | Passed |
| Secret/runtime/backup directory exclusion | Passed |
| Restic data-pack read | 5%; no errors |
| Managed schedule | Four repository-A/media jobs; no B or prune job |
| Scheduled job wrapper | Backup completed with recorded `exit_code=0` status |
| Prune safety gate | Refused execution without `ALLOW_PRUNE=yes` (exit 41) |
| Application least-privilege acceptance | Passed |
| Container state after acceptance | Healthy, running, zero restarts |

The first restore candidate exposed that tests, fictional examples and Git policy files
were not in the snapshot even though the release checksum manifest covered them. The
backup source set was corrected before acceptance. A new snapshot restored the entire
release-verifiable set and passed every checksum. The earlier candidate was not counted
as a successful full recovery.

## Active schedule

- Every six hours: encrypted Restic backup to repository A.
- Weekly: repository A structure and index check.
- Monthly: read 5% of repository A data packs.
- Monthly: verify all currently indexed original-media hashes.

Pruning is intentionally excluded from cron. It remains a supervised operation after a
successful check and restore review.

## Accepted exceptions

- The optional 24-hour runtime soak was waived by the owner; this is an accepted
  residual risk, not a passed test.
- Public ingress remains deferred until the owner purchases a domain. The active site
  remains LAN-only.
- A second cloud provider is not configured by owner decision.
- The owner skipped creation of an additional offline credential pack. Until one is
  created, loss of the target-only Restic password and rclone configuration would make
  the cloud repository unrecoverable even though its data remains intact.

The public source repository is
<https://github.com/xiaojiyiobo/LittleLife>. It contains no archive data, OAuth token,
client secret, Restic password, administrator credential or target network address.
