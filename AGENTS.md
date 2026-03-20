# AGENTS.md

## Repo purpose

This repo provides an Incus-native launcher for upstream app installers from
`community-scripts/ProxmoxVE`.

The upstream ProxmoxVE repo is the source of truth for app definitions and
install scripts. This repo should stay thin.

## Design rules

- Do not fork or copy the upstream app catalog into this repo.
- Fetch upstream `ct/<app>.sh`, `install/<app>-install.sh`, and shared helper
  files on demand.
- Prefer pinned upstream refs for repeatable builds and tests.
- Treat all upstream apps as attemptable by default.
- Do not maintain a local master allowlist of "compatible" apps.
- Maintain only:
  - launcher behavior
  - automation profiles for known interactive apps
  - Incus-specific translation logic
  - test fixtures and docs

## Automation profiles

- A local app entry should exist only when the launcher needs special behavior.
- Examples:
  - preseeded stdin answers
  - app-specific environment injection
  - Incus device or config adjustments beyond the generic path
- If an app works without custom handling, do not add a profile for it.

## Compatibility policy

- "Profiled" does not mean exclusive support. It only means the launcher has
  explicit knowledge for that app.
- Unprofiled apps should still be runnable through the generic flow.
- If an unprofiled app fails, prefer improving generic handling first.
- Add a per-app profile only when the problem is truly app-specific.

## Implementation preferences

- Keep the launcher in Bash unless there is a strong reason to change.
- Favor small composable shell functions over large monolithic scripts.
- Keep network and Incus assumptions minimal. Use the default Incus profile
  unless there is a strong reason not to.
- Avoid embedding large upstream script bodies in this repo.

## Verification

- Validate shell with `bash -n`.
- Prefer dry-run coverage when Incus is unavailable.
- When Incus is available, verify at least:
  - metadata fetch
  - instance creation
  - file push
  - installer execution

## Documentation expectations

- Update `README.md` when CLI behavior changes.
- Document new automation profiles and why they are needed.
- Be explicit about what is generic launcher behavior versus app-specific logic.
