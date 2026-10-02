# Implementation design

## Decision summary

LittleLife uses one authoritative archive and a rebuildable presentation tree:

```text
data/entries + data/media-originals
             |
             | validated one-way build
             v
derived/grav-pages -> Grav 2 -> private HTTP endpoint
```

`data/` is the source of truth. Grav pages, media copies used for browsing, caches,
indexes, thumbnails, and exports are derived. The web application may be deleted and
rebuilt without changing the archive.

## Canonical write workflow

The phase-1 prototype mounted the generated page tree read-only while the write path
was absent. The v1 workflow now uses Grav Admin2 for authentication and its established
API security boundary, but does not let the generic page editor become authoritative.
The thin `littlelife-admin` plugin exposes a purpose-built page inside Admin2 and writes
the canonical Markdown/YAML and original media under `data/`.

Every write holds an archive lock, validates paths and fields, writes Markdown
atomically, snapshots the previous record, appends an audit record, regenerates the
media SHA-256 manifest when media change, and rebuilds `derived/grav-pages`. Original
media are append-only and the UI intentionally has no delete action. The generated
page tree is writable only so this trusted workflow can replace it after a canonical
commit; users do not edit it through the generic Pages screen.

## Archive contract

Each record is one UTF-8 Markdown file below `data/entries/YYYY/`. YAML front matter
contains at least:

- stable `id` (`YYYYMMDD-short-slug`), timezone-aware `date`, `created_at`, `updated_at`;
- human `title` and controlled `type`;
- a list of paths to originals below `data/media-originals`;
- `visibility`, defaulting to `private`.

Original media is append-only. The application never rotates, strips metadata,
compresses, or transcodes it in place. Derivatives receive new files below `derived/`.

## Runtime

The prototype uses the multi-architecture LinuxServer Grav 2.2.4 image, pinned to an
OCI index digest. `/config` is persisted under `runtime/grav-config`; canonical source
data is never mounted into the container. Generated pages and the LittleLife theme are
mounted read-only.

On first launch, a network-isolated bootstrap container initializes the complete Grav
`user/` tree in the runtime volume before any nested read-only mounts are applied. This
is required because pre-creating only pages/theme mount points would make the image skip
its normal plugin initialization.

The host launcher is mandatory. It refuses to run unless `/mnt/mmcblk0p6` is a real
mount point and the configured root resolves beneath it. Calling `docker compose up`
directly bypasses that protection and is prohibited in production.

## Privacy boundary

The container binds only to `127.0.0.1` on the target. Public traffic is expected to
arrive through an authenticated VPS HTTPS endpoint and a controlled FRP tunnel. No
S20M management port is exposed directly by this repository.

## Phase boundaries

1. Phase 0: local, VPS and S20M read-only audit — complete.
2. Phase 1: archive contract, fictional fixture, generator, theme and local tests — complete.
3. Phase 2: LAN-only S20M deployment and canonical Admin2 workflow — complete; optional
   24-hour soak was explicitly waived.
4. Phase 3: tooling and local two-repository exercise — complete; activation against two
   independent offsite providers awaits user-owned accounts and credentials.
5. Phase 4: local restore exercises and documentation — complete; provider-specific
   restores and scheduled offsite checks await phase 3 activation.
6. Phase 5: real-data import only after both independent offsite restore gates pass.

