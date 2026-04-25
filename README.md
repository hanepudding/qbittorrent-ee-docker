# qbittorrent-ee-docker

Minimal Docker packaging of [c0re100/qBittorrent-Enhanced-Edition](https://github.com/c0re100/qBittorrent-Enhanced-Edition) (QBEE).

The image takes the official QBEE static `qbittorrent-nox` binary verbatim from the upstream GitHub release, verifies its SHA256, and ships it on Alpine with `tini` + `su-exec` and PUID/PGID support. No custom patches, no telemetry, no preconfigured WebUI security overrides.

## Image

```
ghcr.io/hanepudding/qbittorrent-ee:<QBEE_VERSION>
```

Tags follow upstream QBEE versions, e.g. `5.1.3.10`. The `latest` tag is automatically pushed by CI whenever a new upstream release is published — `:latest` always points at the most recent QBEE release that this repo's CI has built.

## Supply chain

```
upstream qBittorrent
   ↓
c0re100/QBEE source (one fork)
   ↓
QBEE GitHub release CI → qbittorrent-enhanced-nox_x86_64-linux-musl_static.zip
   ↓
this repo's CI: download + SHA256 verify + package
   ↓
ghcr.io/hanepudding/qbittorrent-ee:<version>
```

The only third-party trust dependency is c0re100's release artifact. Each build embeds the SHA256 it verified into the image labels.

## Usage

```bash
docker run -d \
  --name qbittorrent \
  -p 8080:8080 \
  -p 26881:6881/tcp \
  -p 26881:6881/udp \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Asia/Shanghai \
  -v /mnt/appdata/qbittorrent:/config \
  -v /mnt/anime:/downloads \
  --restart unless-stopped \
  ghcr.io/hanepudding/qbittorrent-ee:5.1.3.10
```

### Environment variables

| Var                          | Default | Notes |
|------------------------------|---------|-------|
| `PUID`                       | 1000    | UID to run qbittorrent-nox as |
| `PGID`                       | 1000    | GID to run qbittorrent-nox as |
| `UMASK`                      | 022     | umask for created files |
| `TZ`                         | UTC     | Timezone (e.g. `Asia/Shanghai`) |
| `WEBUI_PORT`                 | 8080    | Internal WebUI port |
| `ENABLE_DOWNLOADS_PERM_FIX`  | false   | If `true`, run `chown -R abc:abc /downloads` on every start. Off by default — recursive chown on a multi-TB NAS mount can be slow and is rarely needed if the NFS export already has matching UIDs |

### Volumes

| Path         | Notes |
|--------------|-------|
| `/config`    | qBittorrent profile, settings, BT_backup, etc. |
| `/downloads` | Default save path (you can change this in WebUI per-category) |

`/config` is `chown`'d to PUID:PGID on every start. `/downloads` is **not** touched — bring your own permissions (NFS mount, etc.).

### First start

1. Container generates a random temporary admin password and prints it to logs:
   ```bash
   docker logs qbittorrent | grep -i 'password'
   ```
2. Open http://host:8080, login as `admin` with that password, **immediately** change to a real password under Options → Web UI.
3. Recommended hardening (off by default in QBEE; this image does NOT pre-disable them):
   - Options → Web UI → Enable Cross-Site Request Forgery (CSRF) protection: ✅
   - Options → Web UI → Enable Clickjacking protection: ✅
   - Options → Web UI → Enable Host header validation: ✅
   - Options → Web UI → IP subnet whitelist: restrict to your LAN

### Search plugins (not bundled)

This image deliberately ships no search engine plugins. Install via WebUI → Search → "Search plugins" → "Install plugin from URL". The Jackett plugin (most useful for anime) is at:

```
https://raw.githubusercontent.com/qbittorrent/search-plugins/master/nova3/engines/jackett.py
```

## Building locally

```bash
# Compute hash for the version you want
VER=5.1.3.10
SHA=$(curl -fsSL "https://github.com/c0re100/qBittorrent-Enhanced-Edition/releases/download/release-${VER}/qbittorrent-enhanced-nox_x86_64-linux-musl_static.zip" | sha256sum | awk '{print $1}')

docker build \
  --build-arg QBEE_VERSION=$VER \
  --build-arg QBEE_SHA256=$SHA \
  -t qbittorrent-ee:$VER .
```

## CI

| Workflow | Trigger | Action |
|----------|---------|--------|
| `check-upstream.yml` | daily cron @ 04:00 UTC, manual | Looks up the latest QBEE release tag, triggers `build.yml` with that version |
| `build.yml` | `workflow_dispatch` (manual, or invoked by `check-upstream.yml` cron), push to `main` touching Dockerfile/entrypoint | Computes SHA256 of upstream artifact, checks if `ghcr.io/.../qbittorrent-ee:<VER>` already exists, builds & pushes `:<VER>` and `:latest` if not |

The cron-driven flow is the canonical path: every day at 04:00 UTC, if c0re100 has published a new release, this repo builds and pushes both the version tag and `:latest`. Re-runs for an already-built version are a no-op (manifest check), so daily idempotent triggering has zero cost.

Manual `workflow_dispatch` exposes:

- `qbee_version` (required): which version to build
- `push_latest` (default `true`): whether to also tag `:latest`. Set `false` if you're back-filling an old version
- `force` (default `false`): rebuild even if `:<VER>` already exists in GHCR

## Differences from `superng6/qbittorrentee`

| Aspect | superng6/qbittorrentee | this image |
|--------|------------------------|------------|
| Base | Alpine + s6-overlay (~14 MB scaffolding) | Alpine + tini (~few hundred KB) |
| Process supervisor | s6-svscan + s6-supervise | tini PID 1, single child |
| qbittorrent-nox source | upstream QBEE release (verified) | upstream QBEE release (verified, identical hash) |
| SHA256 verification | not in build | yes, in build |
| WebUI security defaults | CSRF/Clickjacking/HostHeader pre-disabled | left at QBEE defaults (enabled) |
| Bundled search plugins | 37 (most for dead sites) | 0 (install via WebUI) |
| PUID/PGID | yes | yes |
| Multi-arch | x86-64, arm64, armhf | x86-64 only |
| Latest tag automation | manual sync from upstream releases | daily cron, auto |
| Build SHA256 verification | not in build | yes, in build |

## License

This packaging is MIT (see `LICENSE`). The packaged binary qBittorrent Enhanced Edition is GPL-2.0-or-later, see [c0re100/qBittorrent-Enhanced-Edition](https://github.com/c0re100/qBittorrent-Enhanced-Edition) for upstream licensing.
