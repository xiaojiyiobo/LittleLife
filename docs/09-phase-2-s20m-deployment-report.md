# Phase 2 S20M deployment report

Deployment date: 2026-10-02 (Asia/Hong_Kong)

## Result

The fictional, read-only LittleLife prototype was deployed successfully on the S20M.
It is healthy on native linux/arm64 and is reachable only through the configured S20M
LAN address on port 8080. No real family data, public ingress, backup credential, FRP
mapping, VPS/Nginx configuration, mount policy, or existing container was changed.

## Deployed version

| Item | Value |
|---|---|
| Git commit | `79e6d48` |
| Project version | `0.1.0-dev` |
| Target root | `/mnt/mmcblk0p6/littlelife` |
| Container | `littlelife-grav` |
| Bind | `ROUTER_LAN_IP:8080` (LAN IPv4 only; real address is target-only) |
| Image digest | `sha256:7eb1a043e5c7ec95203eb4fdcd63294fb15ece82297dfeae0ec32cfa1664570b` |
| Runtime architecture | `linux/arm64` |
| Corrected artifact SHA-256 | `f3d82b04bfc6187b9ea6f3e786cbdc28d1a08a5405e91a3e997f3c5496f92012` |
| Container start | 2026-10-02 20:17:48 +08:00 |

## Verification evidence

| Check | Result |
|---|---|
| Mount guard | `/dev/mmcblk0p6`, ext4, target below verified mount |
| Container state | Running, healthy, zero restarts, not OOM-killed |
| Resource control | 1 CPU / 512 MiB configured; about 47-48 MiB used initially |
| Home, timeline, story, media | HTTP 200 |
| Direct Markdown source | HTTP 403 |
| Listener | Configured LAN IPv4 only; WAN address closed |
| `/overlay` | 37.5 MiB available before and after deployment |
| Data partition | About 103.7 GiB available after image pull |
| Router temperature | About 42.7 C after startup |
| Existing containers | All running, zero restarts, no OOM state |
| Existing services | LunaTV HTTP 307; FRP LunaTV/AdGuard/SSH listeners intact |
| Router gateway | Reachable after deployment |

The image pull and all persistent container/runtime writes used
`/mnt/mmcblk0p6/docker` and `/mnt/mmcblk0p6/littlelife`; no measurable `/overlay`
capacity loss occurred.

## Deployment issue and correction

The first start stopped immediately while sourcing `deploy/.env` because the packaged
copy used CRLF line endings. No LittleLife container was created by that attempt. The
file was normalized to LF, scripts/config were revalidated, and the second start passed.
The local and S20M staging artifacts were rebuilt with SHA-256
`f3d82b04bfc6187b9ea6f3e786cbdc28d1a08a5405e91a3e997f3c5496f92012`.
The prior staging archive was retained with suffix `.pre-crlf-fix` for auditability.

## Rollback

Run `/mnt/mmcblk0p6/littlelife/deploy/stop.sh` with `sh`. This removes only the
LittleLife container and Compose network. Preserve the target directory by renaming it;
do not delete it. Then recheck `/overlay`, Docker, existing containers, DNS/routing, and
FRP. The pinned image can remain in Docker storage unless separately approved for
cleanup.

The LAN-change backup is stored at
`/mnt/mmcblk0p6/littlelife/rollback/20261002-lan-firewall-3d9c4e7`. LAN rollback also
requires deleting the live nftables rule marked `LittleLife_LAN_HTTP_runtime`, restoring
the backed-up `/etc/config/firewall` and Compose files, and recreating the service. Do
not hot-reload firewall4 while the current PassWall dynamic sets are active; validate
network recovery through the existing FRP SSH session.

## Pending gates

- Select a hostname and authentication method before any VPS/FRP ingress change.
- Select two independent backup repositories and perform real backup/restore tests
  before importing real family data.
- Decide whether to replace anonymous automount with an explicitly enabled UUID mount;
  that requires a separately approved controlled reboot test.

## Accepted residual risk

On 2026-10-02, after reviewing the successful initial native ARM64 deployment and its
small workload, the user explicitly cancelled the planned 24-hour soak. The associated
automation was paused. This is recorded as a waived test, not a passed test. Initial
health, resource, storage, routing, and existing-service checks remain valid; sustained
runtime behavior has not been measured.

## LAN-only access change

The user requested LAN-only access because no domain is available yet. The approved
target-specific bind is `ROUTER_LAN_IP:8080`, which is the S20M LAN bridge address. It
does not bind the WAN address, an IPv6 wildcard, FRP, or a VPS listener. The repository
keeps `127.0.0.1` as its safe default; only the S20M deployment `.env` overrides it.

This fictional prototype has no login layer. Do not import real family data until an
authentication design is deployed and tested. Rollback is to set
`LITTLELIFE_BIND_ADDRESS=127.0.0.1` and recreate the Compose service.

ImmortalWRT initially dropped LAN traffic after Docker DNAT because the Compose-created
bridge was not assigned to a firewall zone. The deployed network bridge is
recorded only in the target configuration; a dedicated `littlelife` firewall zone and a single IPv4 TCP/80 rule
from `lan` were saved in UCI. An equivalent live nftables rule was inserted without a
firewall hot reload because current PassWall dynamic sets made reload unsafe. No
LittleLife-to-WAN forwarding, WAN listener, IPv6 wildcard, or FRP mapping was added.
The host-facing published port remains `ROUTER_LAN_IP:8080`.

The default Compose bridge name derives from its persisted Docker network ID. If a
future operation removes and recreates `littlelife_default` (for example, Compose
`down` followed by `up`), its bridge name can change and the scoped firewall device must
be updated and revalidated before LAN access is considered restored.

Final verification from a LAN Windows client returned HTTP 200 for home, timeline,
story, and sample media; direct Markdown remained HTTP 403. The S20M WAN address did
not accept port 8080. Existing containers remained running with zero restarts and
`/overlay` free space remained unchanged.
