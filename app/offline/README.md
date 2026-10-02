# Offline runtime dependencies

`deploy/build-offline-plugin-bundle.sh` creates the ignored, versioned recovery files
in this directory from the verified running Grav instance:

- `grav-plugins.tar.gz`
- `grav-plugins.tar.gz.sha256`

The files belong in release artifacts, target backups and encrypted offline recovery
packs, but not in the public Git repository. `install-grav-plugins.sh` verifies the
checksum and uses this bundle before attempting a network GPM installation.
