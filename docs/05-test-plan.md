# Test plan and acceptance gates

## Automated local tests

1. Validate fictional archive front matter, timestamps, IDs, media confinement, and
   referential integrity.
2. Build Grav pages from source; delete the derived tree and reproduce identical files.
3. Generate and verify SHA-256 manifests; prove corruption is detected.
4. Export an ordinary ZIP and inspect that it contains only open archive files.
5. Render the prototype in the pinned amd64 container and exercise health/home/story.
6. Inspect both amd64 and arm64 manifests; build custom code for both if an image is added.

## S20M gates

- Record firmware, architecture, RAM, filesystem, mount table, `/overlay` and data-disk
  capacity before installation.
- With `/mnt/mmcblk0p6` mounted, start and smoke-test the site.
- Stop the service, simulate the mount being absent without touching real data, and
  prove the launcher refuses to start and creates nothing on `/overlay`.
- Reboot and confirm the mount precedes service startup.
- Soak-test CPU, memory, I/O, temperature, network latency, packet loss, and FRP.
- Compare `/overlay` use before and after; sustained project writes are a failure.

Initial deployment, reboot-order evidence, mount guard, LAN isolation and post-change
resource checks passed. The optional long soak was waived by the user; this is an
accepted residual risk rather than a passing result.

## Backup gates

- Both independent repositories complete first backup and `restic check`.
- Restore one record and one media file independently from each repository.
- Restore all `data/` to a clean location and verify every manifest entry.
- Exercise one repository failure while the other continues.
- Confirm secret scan finds no credentials in Git, image layers, or normal logs.

The complete gate has passed with two disposable local repositories, proving scripts,
checks and restores. It must be repeated with two independent offsite providers before
real family data is imported; local repositories do not satisfy provider independence.

## Release gate

Real family data may be imported only when remote audit, privacy controls, both backup
restores, mount-failure behavior, and a documented recovery exercise have passed.

