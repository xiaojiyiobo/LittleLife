# Future domain and public-ingress runbook

This runbook is intentionally pending. The current approved state is LAN-only.

After a domain is purchased:

1. Choose the exact hostname and confirm its DNS provider supports the required record.
2. Back up the VPS Nginx, FRP and firewall configuration and record current hashes.
3. Create a new dedicated FRP TCP mapping; consult the target-only port inventory and
   do not reuse any existing mapping or expose the S20M management interface.
4. Keep the S20M container bound to its reviewed address; point only the controlled FRP
   client at the LittleLife HTTP service.
5. Configure an Nginx virtual host with TLS, HTTP-to-HTTPS redirect, request-size limits,
   rate limits, security headers and access protection.
6. Obtain and verify a certificate for the exact hostname. Never serve LittleLife from
   the unrelated existing certificate or virtual host.
7. Test login, upload, range requests for video/audio, export, timeouts and maximum body
   size through the full HTTPS path using fictional data.
8. Verify the origin port is not directly reachable from the public Internet and that
   the router UI/SSH ports have not been exposed by the new rule.
9. Record DNS, certificate, Nginx, FRP, container and Git versions plus rollback steps.

Rollback is to remove/disable only the new Nginx virtual host and FRP mapping, reload
their configurations after validation, and leave the LAN service and canonical archive
unchanged.
