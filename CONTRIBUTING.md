# Contributing

## Scope

This project is intentionally thin. The upstream app catalog remains
`community-scripts/ProxmoxVE`.

Good contributions:

- generic Incus compatibility improvements
- better error handling and cleanup behavior
- clearer logs and docs
- automation profiles for interactive upstream installers
- smoke-test coverage for apps validated on real Incus hosts

Less desirable contributions:

- copying the upstream app catalog into this repo
- adding a large local allowlist of "supported" apps
- forking upstream scripts when a generic fix would work

## Development

Basic local checks:

```bash
bash -n bin/incus-app lib/common.sh lib/apps.sh
./bin/incus-app list-supported
./bin/incus-app show adguard --ref main
./bin/incus-app create adguard --dry-run --cleanup-on-failure
./bin/incus-app smoke-test netbird --dry-run --cleanup-on-failure
```

If you have a local checkout of `community-scripts/ProxmoxVE`, you can point
the launcher at it:

```bash
UPSTREAM_RAW_BASE="file:///path/to/ProxmoxVE" ./bin/incus-app show adguard
```

## Compatibility expectations

- Any upstream app may be attempted.
- A launcher profile only means we have app-specific handling for prompts or
  Incus behavior.
- If an unprofiled app fails, prefer fixing the generic path before adding an
  app-specific profile.

## Pull requests

- Keep changes focused.
- Update `README.md` when CLI behavior changes.
- Document newly validated apps.
- Note whether testing was dry-run only or against a real Incus host.
