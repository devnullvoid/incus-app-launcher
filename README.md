# incus-app-launcher

`incus-app-launcher` runs app installers from
[`community-scripts/ProxmoxVE`](https://github.com/community-scripts/ProxmoxVE)
on Incus instead of Proxmox VE.

The launcher stays thin. It does not fork the upstream app catalog. Instead, it
fetches:

- `ct/<app>.sh`
- `install/<app>-install.sh`
- shared helper files

from the upstream repo at a chosen ref, then:

1. Reads the upstream container defaults.
2. Creates an Incus container with similar limits.
3. Bootstraps a small base package set inside the guest.
4. Pushes the upstream installer into the guest.
5. Applies a small automation profile when the launcher knows how to answer
   upstream prompts.

## Status

This project is usable, but still early.

What exists today:

- generic create flow for upstream apps
- generic addon flow for upstream `tools/addon/*.sh` scripts inside existing containers
- prompt detection for upstream installers
- a small set of automation profiles for interactive apps
- dry-run and smoke-test commands
- real-world validation on an Incus VPS

What does not exist yet:

- broad compatibility guarantees across the full upstream app catalog
- complete translation of Proxmox-specific features
- a mature release process

## Support model

- Any upstream app can be attempted.
- The local maintained list is only for launcher automation profiles, not for a
  master allowlist of compatible apps.
- Unprofiled apps use the generic flow and empty stdin unless prompt handling
  is added.
- If an app fails, the first preference is improving generic Incus behavior.
  App-specific profiles should stay small and focused.

## Automation profiles

- `adguard`
- `vaultwarden`
- `netbird`

## Tested apps

Validated on a real Incus 6.21 host:

- `adguard`
- `docker`
- `netbird`
- `dockge` via `addon install dockge` inside a Docker-capable target container

## Requirements

- `bash`
- `curl`
- `awk`
- `sed`
- `mktemp`
- `incus`

## Safety notes

- The launcher uses the existing default Incus profile unless you change the
  code or environment around it.
- It does not modify host-wide Incus profiles, networks, or storage pools.
- Per-instance root disk sizing is done through instance device override, not
  by editing shared profiles.
- `--cleanup-on-failure` only removes a newly created instance when the
  launcher itself fails after creation. Successful runs leave the instance in
  place.

## Usage

List the apps with launcher automation profiles:

```bash
./bin/incus-app list-supported
```

`list-profiled` is an alias:

```bash
./bin/incus-app list-profiled
```

Show the upstream defaults and launcher notes for an app:

```bash
./bin/incus-app show netbird --ref main
```

`show` also scans the fetched installer for common prompt patterns and reports
whether upstream interactivity appears to be present.

Show an unprofiled app and inspect prompt hints:

```bash
./bin/incus-app show pihole --ref main
```

Create an app container:

```bash
./bin/incus-app create netbird --name netbird --ref main
```

Run upstream prompts interactively in your terminal:

```bash
./bin/incus-app create docker --name docker-test --prompt-mode interactive
```

Run an upstream addon script inside an existing container:

```bash
./bin/incus-app addon install dockge --target docker-host --prompt-mode interactive
```

Run an addon update flow inside an existing container:

```bash
./bin/incus-app addon update dockge --target docker-host --prompt-mode interactive
```

Delete the instance automatically if creation fails:

```bash
./bin/incus-app create netbird --name netbird --cleanup-on-failure
```

Run a basic smoke test after creation:

```bash
./bin/incus-app smoke-test adguard --name adguard-smoke --cleanup-on-failure
```

Pin to a specific upstream commit:

```bash
./bin/incus-app create adguard \
  --name adguard \
  --ref 4a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8g9
```

Print the Incus commands without executing them:

```bash
./bin/incus-app create vaultwarden --name vaultwarden --dry-run
```

Override the upstream raw base, useful for local development:

```bash
UPSTREAM_RAW_BASE="file:///home/jon/Dev/github/ProxmoxVE" \
  ./bin/incus-app show adguard
```

## Notes

- Upstream has two relevant models:
  - app containers driven by `ct/<app>.sh` plus `install/<app>-install.sh`
  - addon scripts driven by `tools/addon/<name>.sh`
- Addons are meant to run inside an existing target container, not through the
  normal app-creation path.
- `dockge` is the current example of an upstream addon-oriented workflow.
- Public repo hardening includes CI for syntax and dry-run smoke coverage.
- `netbird` is interactive upstream. The launcher answers the prompts with:
  managed deployment and "skip connection for now".
- Prompt modes:
  - `profile`: use launcher-provided answers when a profile exists
  - `empty`: feed empty stdin
  - `interactive`: attach upstream prompts to the current terminal
- Addon commands support `interactive` and `empty` prompt modes.
- Some upstream scripts still assume a Proxmox environment. Unprofiled apps are
  attempted with empty stdin and may still need manual fixes or more launcher
  automation.
- The launcher defaults to `main` if `--ref` is not set, but using a pinned
  commit is recommended for repeatable builds.
- The MVP uses your existing Incus default profile and network. Custom network
  selection is not automated yet.
