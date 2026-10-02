# Baidu Netdisk repository-B acceptance

Date: 2026-10-03

The reference ARM64 deployment uses the pinned OpenList container as a LAN-only
WebDAV bridge. OpenList authenticates to a private Baidu developer application, while
rclone authenticates to a dedicated OpenList user restricted to `/baidu-backup`.
OAuth tokens, WebDAV credentials and the independent Restic password remain only in
the target `secrets/` directory and the owner's offline recovery pack.

## Acceptance evidence

| Check | Result |
| --- | --- |
| OpenList storage state | Working |
| WebDAV read and write | Passed |
| Independent Restic repository initialization | Passed |
| Initial repository-B backup | Passed |
| `restic check` | Passed |
| Restore into a new empty directory | Passed; 152 files/directories, 10.279 MiB |
| Release checksum verification after backup-contract fix | Passed |
| Managed repository-B schedule | Installed |

The acceptance restore exposed that the original backup root list omitted `LICENSE`
and `README.zh-CN.md` even though both were required by the release checksum manifest.
The backup contract now includes them and has an automated regression test. The
repository was backed up and restored again before acceptance was recorded.

## Network and security boundaries

- The management and WebDAV endpoint binds only to the LittleLife LAN address.
- The public VPS tunnel does not expose OpenList.
- The LittleLife container zone permits outbound IPv4 TCP 443 for provider APIs; no
  new public inbound rule was added.
- Repository A remains independent and unchanged.
- Automated pruning remains disabled and requires an explicit supervised operation.
