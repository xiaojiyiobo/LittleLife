# Directory mapping

## Target device

```text
/mnt/mmcblk0p6/littlelife/
├── data/                 authoritative archive; highest backup priority
│   ├── profile/
│   ├── entries/
│   ├── media-originals/
│   ├── manifests/
│   └── exports/
├── derived/              disposable and rebuildable
│   └── grav-pages/
├── app/                  deployed theme/integration code
├── config/               non-secret configuration
├── secrets/              target-only, never Git
├── runtime/              Grav `/config`, cache and logs
├── backup/               backup logs, locks and restore staging
└── scripts/              deployed operational scripts
```

## Container mounts

| Host | Container | Mode | Class |
|---|---|---|---|
| `runtime/grav-config` | `/config` | read/write | Runtime |
| `derived/grav-pages` | `/config/www/user/pages` | read-only | Derived |
| `app/littlelife-theme` | `/config/www/user/themes/littlelife` | read-only | Code |
| `config/grav/system.yaml` | `/config/www/user/config/system.yaml` | read-only | Config |
| `config/grav/site.yaml` | `/config/www/user/config/site.yaml` | read-only | Config |
| `config/grav/themes/littlelife.yaml` | `/config/www/user/config/themes/littlelife.yaml` | read-only | Config |
| `config/grav/plugins/admin2.yaml` | `/config/www/user/config/plugins/admin2.yaml` | read-only | Config |
| `config/grav/plugins/api.yaml` | `/config/www/user/config/plugins/api.yaml` | read-only | Config |
| `config/grav/plugins/littlelife-admin.yaml` | `/config/www/user/config/plugins/littlelife-admin.yaml` | read-only | Config |

The parent `user/config/plugins/` directory remains part of writable target-only runtime
so Grav API can create `api-private.php`, its JWT signing secret. That secret is never
mounted from source control and is included only in protected runtime backups and the
offline recovery pack.

The container has no mount of `data/media-originals`. Only validated, copied derivatives
are presented to the web server. This narrows accidental write and disclosure paths.

## Workspace placement

- Source: `D:\AI-Projects\01_Projects\LittleLife`
- Disposable build/probe data: `D:\AI-Projects\02_Builds\LittleLife-*`
- Future release bundles: `D:\AI-Projects\03_Artifacts\LittleLife-<version>-<commit>`
- Approved deployment snapshot: `D:\AI-Projects\04_Deploy\LittleLife\<version>`
- Recovery/maintenance reports: `D:\AI-Projects\05_Docs\LittleLife`

