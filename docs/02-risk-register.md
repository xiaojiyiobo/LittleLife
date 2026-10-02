# Risk register

| ID | Risk | Severity | Current control | Exit condition |
|---|---|---:|---|---|
| R1 | `/mnt/mmcblk0p6` absent and Docker creates directories on `/overlay` | Critical | Mandatory host preflight; no remote deployment yet | Reboot/mount-failure tests pass on S20M |
| R2 | Router storage failure loses online archive | Critical | Two independent off-site repos planned | Both repos restore successfully |
| R3 | Grav becomes a second data source | High | Generated pages are read-only | Atomic canonical write workflow tested |
| R4 | Public exposure leaks family data | Critical | Loopback-only bind; public config deferred | TLS, auth, FRP and external scan pass |
| R5 | Credentials enter Git/logs/images | Critical | `.gitignore`, templates only, separate secret directory | Secret scan and permission audit pass |
| R6 | Sustained ARM64/S20M behavior not verified | Medium | Native smoke test passed; user waived 24-hour soak on 2026-10-02 | Re-run soak before a major upgrade or if instability appears |
| R7 | Docker load disrupts routing | High | Conservative resource limits planned | Soak test shows network/thermal stability |
| R8 | WSL system disk disconnect interrupts builds | Medium | Failure recorded; source remains on `D:` | Documented recovery test succeeds |
| R9 | Restic prune amplifies repository damage | High | Separate manual guarded job; staggered repos | Check + restore precede every prune policy |
| R10 | Silent corruption of originals | High | SHA-256 manifest and verification tooling | Scheduled sample/full verification passes |
| R11 | Unsupported media or unsafe filenames | High | Validator confines paths to archive root | Upload pipeline fuzz/security tests pass |
| R12 | Long-term format/tool obsolescence | Medium | Open files, annual export and DR exercise | Annual readability review completed |
| R13 | Grav/image upgrades break custom theme | Medium | Version/digest pin and staging gate | Upgrade test and rollback pass |
| R14 | Two cloud copies share one failure domain | High | Storage decision explicitly pending | Different provider/account/credential sets |
| R15 | VPS FRP/application ports are publicly reachable while host input policy accepts traffic | High | No LittleLife listener or ingress change made | Firewall scope, HTTPS auth, rate limits, and external scan pass |
| R16 | S20M data partition relies on anonymous automount while its explicit UUID entry is disabled | Medium | Startup preflight refuses an absent/wrong mount; current boot mount verified | Approved explicit mount policy and controlled reboot test pass |

