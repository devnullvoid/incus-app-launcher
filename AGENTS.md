# AGENTS.md

## Repo purpose

This repo provides an Incus-native launcher for upstream app installers from
`community-scripts/ProxmoxVE`.

The upstream ProxmoxVE repo is the source of truth for app definitions and
install scripts. This repo should stay thin.

There are two upstream integration models:

- App model:
  - `ct/<app>.sh`
  - `install/<app>-install.sh`
- Addon model:
  - `tools/addon/<name>.sh`
  - runs inside an existing container instead of creating a new one

## Design rules

- Do not fork or copy the upstream app catalog into this repo.
- Fetch upstream `ct/<app>.sh`, `install/<app>-install.sh`, and shared helper
  files on demand.
- Fetch upstream `tools/addon/<name>.sh` on demand for addon workflows.
- PocketBase metadata may be used to enrich discovery and route selection, but
  not as the execution source of truth.
- Prefer pinned upstream refs for repeatable builds and tests.
- Treat all upstream apps as attemptable by default.
- Do not maintain a local master allowlist of "compatible" apps.
- Maintain only:
  - launcher behavior
  - automation profiles for known interactive apps
  - addon execution behavior for existing containers
  - optional metadata enrichment behavior
  - Incus-specific translation logic
  - test fixtures and docs

## Automation profiles

- A local app entry should exist only when the launcher needs special behavior.
- Examples:
  - preseeded stdin answers
  - app-specific environment injection
  - Incus device or config adjustments beyond the generic path
- If an app works without custom handling, do not add a profile for it.

## Addon policy

- Prefer addon execution for upstream tools that no longer have a normal
  `install/<app>-install.sh` path.
- Dockge is the reference example.
- Do not try to force addon-oriented upstream tools through the normal
  app-creation path unless upstream restores a first-class installer flow.
- Addon commands should target an existing Incus container and keep host-level
  assumptions minimal.

## Compatibility policy

- "Profiled" does not mean exclusive support. It only means the launcher has
  explicit knowledge for that app.
- Unprofiled apps should still be runnable through the generic flow.
- If an unprofiled app fails, prefer improving generic handling first.
- Add a per-app profile only when the problem is truly app-specific.

## Metadata policy

- Treat PocketBase as an optional metadata layer.
- Use it for:
  - discovery
  - search
  - script-type labeling
  - dev/prod labeling
  - disabled/deleted visibility
- Do not rely on PocketBase alone for install behavior, prompt handling, or
  Incus runtime decisions when the upstream scripts disagree.

## Implementation preferences

- Keep the launcher in Bash unless there is a strong reason to change.
- Favor small composable shell functions over large monolithic scripts.
- Keep network and Incus assumptions minimal. Use the default Incus profile
  unless there is a strong reason not to.
- Avoid embedding large upstream script bodies in this repo.
- Match upstream defaults when they materially affect container behavior.
  Current example: default nesting should behave like upstream `build.func`.

## Verification

- Validate shell with `bash -n`.
- Prefer dry-run coverage when Incus is unavailable.
- When Incus is available, verify at least:
  - metadata fetch
  - instance creation
  - file push
  - installer execution
  - addon execution inside an existing container when addon behavior changes

## Documentation expectations

- Update `README.md` when CLI behavior changes.
- Update `CHANGELOG.md` for user-visible behavior changes.
- Document new automation profiles and why they are needed.
- Be explicit about what is generic launcher behavior versus app-specific logic.
