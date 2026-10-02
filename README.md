# LittleLife

[English](README.md) | [简体中文](README.zh-CN.md)

LittleLife is an open-source, self-hosted family timeline and long-term media archive.
It keeps stories in Markdown/YAML and original photos, video and audio as ordinary
files, so the archive remains readable even if the website, container or CMS is gone.

The code is public and reusable. Each installation keeps its family data, account
credentials and backup keys on storage controlled by that user; none of those belong in
this repository.

## Why LittleLife

- **Open archive:** no database is required as the source of truth.
- **Original media:** uploaded source files are preserved and covered by SHA-256
  manifests.
- **Replaceable website:** Grav is a browsing and editing layer over ordinary files.
- **Source/derived split:** previews, generated pages and caches can be rebuilt.
- **Portable deployment:** validated on Linux ARM64 and amd64 with Docker Compose.
- **Recoverable backups:** Restic + rclone scripts support one required repository and
  an optional independent second repository, checks and fresh-directory restores.
- **Conservative operations:** mount preflight, job locks, least-privilege admin access,
  supervised pruning and rollback-oriented deployment.

## Included features

- Authenticated creation and editing of timeline records
- Original photo, video and audio upload with collision-safe names
- Year, month, tag and milestone filters
- Family profile and timeline views
- Audit/history records and SHA-256 integrity checks
- Open-format ZIP export
- Six-hour backup scheduling, weekly repository checks and monthly data-pack/media
  verification
- Pinned Grav/plugin versions and an offline-plugin-bundle workflow

## Get started

Read the [public quick start](docs/17-public-quickstart.md) for a fictional demo on a
Linux host with Docker. The deployment must live on a real mounted data filesystem;
the preflight intentionally refuses an unmounted or unsafe target.

For the design and data contract, continue with:

- [Implementation design](docs/01-implementation-design.md)
- [Directory mapping](docs/03-directory-mapping.md)
- [Backup and recovery plan](docs/04-backup-recovery-plan.md)
- [Administrator guide](docs/11-admin-user-guide.md)
- [Offline recovery pack](docs/14-offline-recovery-pack.md)

## Reference deployment status

The reference deployment has passed native ARM64 application, least-privilege,
independent Google Drive and Baidu Netdisk backups, repository checks and
clean-directory restore acceptance. Public ingress is optional and is not required for
a LAN-only installation. See the [Google Drive acceptance record](docs/16-google-drive-backup-acceptance.md)
and [Baidu repository-B acceptance record](docs/18-baidu-backup-acceptance.md) for the
recorded evidence and accepted exceptions.

## Repository layout

```text
app/             Grav theme and thin integration code
config/          Non-secret configuration templates
data-schema/     Machine-readable archive contracts
examples/        Fictional test archive only
scripts/         Validation, integrity, backup and restore tooling
deploy/          Source-controlled deployment templates
docs/            Design, risks, runbooks and audit results
tests/           Automated checks
```

Never commit real family media, archive records, OAuth tokens, administrator
credentials, Restic passwords, `rclone.conf`, private keys or target network details.
The optional Google Drive integration and its limited data use are described in the
[privacy policy](docs/15-privacy-policy.md).

## License

LittleLife is available under the [MIT License](LICENSE).
