# LAN administration change plan

## Scope

Enable Grav Admin2 on the already approved LAN-only endpoint and add a thin
`littlelife-admin` plugin. Admin2 supplies authentication and token handling. The
plugin writes canonical Markdown/YAML and original media directly below `data/`,
updates the SHA-256 manifest, appends an audit record, and rebuilds the disposable
Grav page tree.

The change does not add a WAN listener, VPS route, FRP proxy, domain, database, or
third-party account. The existing bind remains `ROUTER_LAN_IP:8080` until the user
purchases a domain and separately authorizes public ingress.

## Expected impact

- `data/` is mounted read/write only into the trusted Grav container so the custom
  authenticated plugin can commit archive changes.
- `derived/grav-pages` changes from read-only to read/write because a successful
  canonical write immediately rebuilds presentation pages.
- Admin2 and its API become reachable at `/admin2` and `/api/v1` on the same LAN-only
  socket.
- One administrator account is created in the target-only Grav runtime. Its generated
  password is stored only in `secrets/admin-password.txt` with mode `0600`.
- Editing creates an immutable pre-edit snapshot under `data/manifests/history/`.
  Original media are append-only; there is deliberately no delete endpoint.

## Backups before change

1. Windows source snapshot in `D:\AI-Projects\06_Backups\LittleLife`.
2. Target copy of the previous deploy/config/app files and Grav account/config state
   below `/mnt/mmcblk0p6/littlelife/rollback/`.
3. Hashes and container/image/network state captured in the deployment report.

## Rollback

1. Stop only `littlelife-grav`.
2. Restore the saved Compose file, plugin configuration and `app/` snapshot.
3. Restore the pre-change derived page tree if required; canonical `data/` is never
   deleted by rollback.
4. Start through `deploy/start.sh`, verify the old browsing endpoints, and remove the
   live LAN firewall rule only if the entire LittleLife service is intentionally
   withdrawn.

The administrator account and runtime files can remain inert during rollback. Do not
delete uploaded originals; restore or reconcile canonical records from their history
snapshots instead.

## Verification

- PHP and JavaScript syntax checks; existing archive unit tests.
- Compose render, mount preflight and container health.
- Anonymous API write denied and Admin2 login available.
- Authenticated create, edit, media upload, manifest verification, rebuild and export
  against fictional test data only.
- Home, timeline, story and media browse smoke tests.
- Bind remains LAN-address-only; WAN-side address and IPv6 wildcard remain closed.
- Existing containers, `/overlay` usage, temperature and LittleLife restart count are
  compared before and after.
