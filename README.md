# incus-app-launcher

`incus-app-launcher` is a small launcher for running apps from the
official `community-scripts/ProxmoxVE` catalog on Incus instead of Proxmox VE.

It does not fork the upstream app catalog. Instead, it fetches the required
`ct/<app>.sh`, `install/<app>-install.sh`, and shared helper files from the
upstream repo at a chosen ref, then:

1. Reads the upstream container defaults.
2. Creates an Incus container with similar limits.
3. Pushes the upstream installer into the guest.
4. Applies a small automation profile when the launcher knows how to answer
   upstream prompts.

## MVP scope

Initial automation profiles:

- `adguard`
- `vaultwarden`
- `netbird`

Current goals:

- Keep the upstream ProxmoxVE repo untouched.
- Make installs deterministic via `--ref`.
- Support a first set of low-complexity apps plus one interactive example.
- Avoid maintaining a full local allowlist of upstream apps.

Current non-goals:

- Full parity with Proxmox storage, backup, tags, descriptions, or host tools.
- Rich translation of every Proxmox-specific feature.

## Requirements

- `bash`
- `curl`
- `awk`
- `sed`
- `mktemp`
- `incus`

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

Create an app container:

```bash
./bin/incus-app create netbird --name netbird --ref main
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

- `netbird` is interactive upstream. The launcher answers the prompts with:
  managed deployment and "skip connection for now".
- Any upstream app can be attempted. The local maintained list is only for
  automation profiles, not for general app availability.
- Some upstream scripts still assume a Proxmox environment. Unprofiled apps are
  attempted with empty stdin and may still need manual fixes or more launcher
  automation.
- `--cleanup-on-failure` only removes the new instance when the launcher fails
  after creating it. Successful runs leave the instance in place.
- The launcher defaults to `main` if `--ref` is not set, but using a pinned
  commit is recommended for repeatable builds.
- The MVP uses your existing Incus default profile and network. Custom network
  selection is not automated yet.
