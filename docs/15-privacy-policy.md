# LittleLife privacy policy

Effective date: 2026-10-02

LittleLife is a self-hosted, LAN-only family archive. It is not a hosted service and
does not operate a central user database, analytics service or advertising system.

## Google Drive access

The optional backup integration requests Google's `drive.file` scope. It uses that
scope only to create and manage encrypted Restic repository objects that LittleLife's
rclone configuration created in the owner's Google Drive. It does not request access
to unrelated Drive files.

Canonical archive records and original media stay on the owner's device. Before cloud
storage, Restic encrypts backup contents and metadata with the owner's repository
password. OAuth tokens, Restic passwords and rclone configuration remain in the
target-only `secrets/` directory and encrypted offline recovery packs; they are not
included in this public repository, ordinary logs or website exports.

## Sharing and retention

LittleLife does not sell or share archive data with third parties. Google stores the
encrypted backup objects under the owner's Google account according to Google's terms.
Backup retention is controlled by the owner through the documented Restic policy.

The owner can stop future access at any time by removing the LittleLife connection from
their Google Account permissions and disabling the local backup schedule. Revoking the
connection does not automatically delete existing encrypted backup objects; the owner
may retain or delete those separately after confirming another recoverable copy exists.

## Questions

For questions about this software or policy, open an issue in the public LittleLife
GitHub repository without including family data, credentials or device addresses.
