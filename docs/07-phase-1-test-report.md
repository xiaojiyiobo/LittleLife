# Phase 1 test report

Test date: 2026-10-02 (Asia/Hong_Kong)

## Result

The local archive contract and read-only Grav browsing prototype passed. A read-only
VPS audit also completed. No S20M setting, VPS setting, remote storage, credential, or
real family data was changed.

## Evidence

| Test | Result |
|---|---|
| Python unit tests | 3/3 passed |
| Archive validation | 1 record and 1 referenced media file valid |
| SHA-256 manifest | Generated and verified; mutation test detected corruption |
| Derived page build | 1 story and 1 media copy generated |
| Python bytecode compile | Passed |
| POSIX shell syntax | Passed for deploy/backup/restore scripts |
| Compose configuration expansion | Passed |
| Grav image manifest | `linux/amd64` and `linux/arm64` present |
| Container health | Healthy on local linux/amd64 Docker Engine |
| HTTP smoke test | Home, timeline, and story returned 200 |
| Media smoke test | Fictional SVG returned 200 as `image/svg+xml` |
| Source/config web access | Markdown and YAML requests returned 403 |
| Mount preflight success path | Passed on the local `/mnt/d` test mount |
| Mount preflight failure path | Missing mount refused with exit code 20 |
| Secret-pattern scan | No matching credential/private-key material found |

The runtime bootstrap was also tested from a blank directory. It initialized Grav with
networking disabled before the read-only nested mounts were added. This corrected an
observed failure where pre-created nested mounts caused the image to skip its plugin
tree initialization.

## Rollback

This phase is isolated to the Git repository and disposable directories below
`D:\AI-Projects\02_Builds\LittleLife-*`. Rollback is to stop/remove the local test
container and discard the feature branch or build directories. No production rollback
is required because nothing was deployed.

## Remaining risks / blockers

- VPS and S20M phase-0 read-only audits completed. Native ARM64 runtime and sustained
  S20M resource/network behavior remain untested until deployment is approved.
- Native ARM64 runtime behavior is not yet tested; only its image manifest is verified.
  The local x86_64 engine returned `exec format error` for an ARM64 one-shot because
  binfmt/QEMU emulation is not registered. No privileged binfmt system change was made.
- Admin2/API are intentionally disabled until an atomic canonical write/upload workflow
  and authenticated ingress exist.
- Restic/rclone scripts have syntax/config checks only; two actual repositories are not
  selected and no backup/restore has run.
- The target mount was present early in the current boot and Docker already uses it,
  but the explicit UUID entry is disabled and a controlled reboot test has not run.

## Next safe step

Review and approve `docs/08-s20m-deployment-change-plan.md`. The next write operation,
if approved, is a loopback-only fictional prototype with mount guards and conservative
resource limits; public ingress and real data remain separate later changes.
