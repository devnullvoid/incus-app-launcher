# Changelog

## Unreleased

- Added `addon install` and `addon update` to run upstream addon scripts inside
  existing Incus containers.
- Validated Dockge addon installation inside a disposable Docker container on a
  real Incus host.
- Added interactive prompt passthrough for upstream installers.
- Improved smoke-check diagnostics and stabilized the Docker smoke-test path.
- Matched upstream default nesting behavior for Docker-style workloads.

## 2026-03 MVP

- Initial Incus app launcher for upstream `community-scripts/ProxmoxVE` apps.
- Generic app creation flow with metadata parsing from `ct/*.sh`.
- Prompt detection and lightweight automation profiles for selected apps.
- Real-world validation on an Incus VPS.
