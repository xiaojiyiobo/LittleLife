# S20M deployment change plan

Prepared: 2026-10-02 (Asia/Hong_Kong)

Status: awaiting explicit approval; nothing in this plan has been written to S20M.

## Scope

Deploy only the fictional read-only prototype to `/mnt/mmcblk0p6/littlelife`. The
service binds to `127.0.0.1:8080`, so it is not reachable from LAN, WAN, or FRP. No real
family data, backup credentials, rclone configuration, domain, Nginx, firewall, FRP,
mount, or router service setting is included.

## Proposed changes

1. Re-run the mount/device preflight before any write.
2. Upload the versioned deployment bundle to a staging directory on
   `/mnt/mmcblk0p6`, verify its SHA-256 manifest, then rename it into place.
3. Pull the pinned multi-architecture Grav image by digest. Docker already stores
   images and layers below `/mnt/mmcblk0p6/docker`.
4. Initialize Grav runtime with networking disabled, then start one container named
   `littlelife-grav` on loopback port 8080.
5. Limit the container to 1 CPU and 512 MiB RAM and rotate its JSON logs at 3 x 10 MiB.
6. Load only the fictional sample archive and generated pages for native ARM64 testing.

Expected impact: temporary download and CPU/I/O activity during the first image pull
and initialization; steady-state memory is expected to remain below the 512 MiB limit.
No router reboot or interruption to LunaTV, DNS, FRP, routing, or existing containers is
planned.

## Stop conditions

Do not start, or stop immediately, if any of the following occurs:

- `/mnt/mmcblk0p6` is absent, is not ext4, or resolves to the overlay filesystem.
- `/overlay` free space drops materially from the recorded 37.5 MiB baseline.
- Available RAM falls below 512 MiB, temperature exceeds 75 C, or load remains high.
- Existing containers restart, routing/DNS/FRP tests fail, or port 8080 becomes occupied.
- Image architecture is not linux/arm64 or container health does not become healthy.

## Rollback

1. Run `deploy/stop.sh` to stop and remove only the `littlelife-grav` container/network.
2. Preserve the entire LittleLife directory by renaming it with a timestamp; do not
   delete it during rollback.
3. Recheck existing container status, route/DNS/FRP reachability, temperature, memory,
   `/overlay`, and `/mnt/mmcblk0p6` free space.
4. The pinned image may remain in Docker storage; removing it is a separate optional
   cleanup after verification.

## Verification

- Container health is healthy and restart count remains zero.
- Home, timeline, story, and sample media return HTTP 200 through 127.0.0.1:8080.
- Direct requests for Markdown and YAML source files return HTTP 403.
- Docker root remains `/mnt/mmcblk0p6/docker`; all LittleLife paths resolve below the
  data partition; `/overlay` does not receive sustained writes.
- Existing containers remain healthy/running and router DNS/routing/FRP remain usable.
- Record 15-minute initial metrics, then run a 24-hour soak before any ingress work.

## Later, separately approved ingress

The target-only inventory records an allowlisted unused FRP port and several occupied
ports that must not be reused. A future change may map a newly reviewed dedicated port
to the S20M service, followed by an authenticated HTTPS Nginx hostname. That is
explicitly outside this deployment and requires a hostname, authentication design,
firewall review, rollback steps, and fresh approval.
