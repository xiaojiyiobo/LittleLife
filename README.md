# LittleLife

LittleLife is a private, long-lived family archive built around ordinary files:
Markdown/YAML for stories and untouched original media for photos, video, and audio.
Grav is the browsing and editing layer; it is not the source of truth.

This repository contains code, non-secret configuration templates, tests, and operating
documentation. Real family data and credentials must never be committed.

## Current status

- Phase 0 local, VPS, and S20M read-only audits: complete. Target findings are recorded
  in `docs/00-baseline-audit.md`.
- Phase 1 archive contract and local prototype: complete on
  `feature/phase-1-foundation`.
- Phase 2 fictional LAN-only site and authenticated canonical admin: deployed on S20M
  and passed native
  ARM64 smoke/safety checks. The optional 24-hour soak was waived by the user on
  2026-10-02; sustained-runtime risk remains accepted rather than tested.
- Timeline browsing supports combined year, month, tag and milestone filters without
  changing canonical files.
- Restic/rclone ARM64 tools and optional two-repository restore scripts: installed and
  proven against two local acceptance repositories. The owner selected one Google Drive
  repository for the initial deployment; production activation awaits its first cloud
  backup and restored-copy acceptance.
- Public ingress is deferred until a domain is purchased. Real-data import remains
  gated on a successful restore from the selected Google Drive repository.

Start with [`docs/01-implementation-design.md`](docs/01-implementation-design.md) and
[`docs/05-test-plan.md`](docs/05-test-plan.md).

## Repository layout

```text
app/             Grav theme and thin integration code
config/          Non-secret configuration templates
data-schema/     Machine-readable archive contracts
examples/        Fictional test archive only
scripts/         Validation, integrity, backup, and restore tooling
deploy/          Source-controlled deployment templates
docs/            Design, risks, runbooks, and audit results
tests/           Automated checks
```

The target-device deployment root is `/mnt/mmcblk0p6/littlelife`. The authoritative
archive lives under its `data/` directory. Derived content, caches, logs, and container
state are separate and disposable.

The optional Google Drive integration and its limited data use are described in
[`docs/15-privacy-policy.md`](docs/15-privacy-policy.md).
