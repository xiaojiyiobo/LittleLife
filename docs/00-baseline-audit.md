# Phase 0 baseline audit

Audit date: 2026-10-02 (Asia/Hong_Kong)

## Verified local facts

| Item | Observed state |
|---|---|
| Windows host | Windows 10 Pro 64-bit (hostname intentionally omitted) |
| Git | 2.55.0.windows.3 |
| WSL | Ubuntu 22.04, WSL2, x86_64 |
| WSL root filesystem | ext4, about 1007 GiB total, 953 GiB available at audit time |
| Docker Engine | 29.8.1, linux/amd64, `overlayfs` |
| Docker data root | `/var/lib/docker` on the WSL system disk |
| Buildx / BuildKit | 0.37.1 / 0.33.0 |
| Compose | 5.5.1 |
| Project drive in WSL | `D:` mounted at `/mnt/d` using drvfs/9p |
| Existing LittleLife repository | None before this audit |

The Linux system disk was initially absent. WSL returned
`CreateInstance/MountDisk/ERROR_PATH_NOT_FOUND`; after the disk was reconnected,
Ubuntu and Docker became available again. This is evidence that local build continuity
depends on that removable/externally connected system disk.

Windows has no Docker CLI in the interactive PATH. Docker is operated inside WSL. Do
not assume the old Docker Desktop path recorded in the workspace README still exists.

## Container-image verification

The selected prototype image is:

`lscr.io/linuxserver/grav:2.2.4@sha256:7eb1a043e5c7ec95203eb4fdcd63294fb15ece82297dfeae0ec32cfa1664570b`

The registry manifest was inspected on 2026-10-02 and contains both `linux/amd64`
and `linux/arm64`. A local amd64 probe confirmed that `/app/www/public/user` resolves
to `/config/www/user` after initialization and that pages/plugins/config persist below
`/config/www/user`.

## Verified VPS facts

The VPS was inspected read-only through SentinelX on 2026-10-02. No configuration,
service, firewall, tunnel, or certificate changes were made.

| Item | Observed state |
|---|---|
| Host / OS | Ubuntu 22.04.5 LTS, x86_64, kernel 5.15 |
| Capacity | 1 vCPU, 1.9 GiB RAM, 2 GiB swap; 30 GiB ext4 root with about 19 GiB free |
| Core services | Nginx, Docker, and `frps` active |
| Docker | Engine 29.8.1, `overlayfs`, data root `/var/lib/docker`; one healthy Homepage container |
| Nginx | Configuration test passed; public listeners on ports 80 and 443 |
| TLS | An unrelated existing Let's Encrypt certificate was valid during the audit |
| Existing S20M path | An unrelated site already used Nginx and a loopback FRP mapping |
| FRP server | Active with token authentication and a restricted remote-port allowlist |
| FRP mappings | Existing management and application mappings were recorded privately |
| Firewall | UFW inactive; nftables input policy accepts traffic, apart from Docker-managed forwarding rules |

Several unrelated public services also exist on the VPS. LittleLife must not reuse an
occupied port, and no new public listener should be added until ingress authentication
and firewall scope have been reviewed. Exact addresses and ports are intentionally kept
out of the public repository.

The SSH tunnel to S20M was reachable, but both the VPS and the Windows user's
existing Ed25519 key were rejected by the router. Password guessing and key changes were
not attempted. This proves tunnel reachability but does not complete the S20M audit.

## Verified S20M facts

The S20M was inspected read-only over its existing FRP SSH tunnel on 2026-10-02.
No file, service, container, mount, firewall, or network setting was changed.

| Item | Observed state |
|---|---|
| Device / OS | Super Gateway S20M, ImmortalWRT SNAPSHOT `r0-820d563`, kernel 6.18.44 |
| Architecture | `aarch64_cortex-a53`, 4 ARMv8 cores |
| Capacity | About 1.94 GiB RAM, about 1.39 GiB available; no swap |
| Load / temperature | 0.07/0.05/0.03 and 42.6 C at audit time |
| Overlay | f2fs, 102.6 MiB total, 37.5 MiB available |
| Data partition | `/dev/mmcblk0p6`, ext4, 111.7 GiB total, about 104 GiB available |
| Mount evidence | Mounted read/write at `/mnt/mmcblk0p6` 12.6 seconds into the current boot |
| Mount policy | `fstab` service enabled; global anonymous automount enabled; explicit UUID entry exists but has `enabled=0` |
| Docker | Engine 29.6.1 / Compose 5.5.0, native linux/arm64, 4 CPUs, cgroup v2 |
| Docker data root | `/mnt/mmcblk0p6/docker`, overlayfs/containerd snapshotter |
| Existing containers | `ddnsto`, `lunatv`, and `lunatv-kvrocks`; all running, zero restarts, no OOM state |
| Existing load | Containers used about 265 MiB combined at the audit snapshot; LunaTV dominated usage |
| Existing app port | LunaTV publishes host port 3000; proposed LittleLife loopback port 8080 was unused |
| FRP client | Running from `/mnt/mmcblk0p6/frp`; existing mappings include SSH, LunaTV, and AdGuard |

The current boot log showed ext4 journal recovery followed by a successful read/write
mount, with no observed mmc/ext4 I/O or corruption error. A real controlled reboot test
was not performed because that would interrupt routing. The deployment preflight must
continue to require both the mount and the expected ext4 device before any directory or
container creation.

## Still not verified or selected

- The two independent off-site storage providers and their quotas/costs.
- The intended LittleLife hostname, ingress authentication method, and dedicated FRP
  remote port.
- S20M behavior during the proposed LittleLife ARM64 container start and a sustained
  soak test.

No real-data import, public ingress, or backup activation may occur until the remaining
items are approved and tested. A loopback-only fictional prototype may be deployed only
after review of `docs/08-s20m-deployment-change-plan.md`.

