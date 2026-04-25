#!/bin/bash
set -euo pipefail

PUID="${PUID:-1000}"
PGID="${PGID:-1000}"
UMASK="${UMASK:-022}"
WEBUI_PORT="${WEBUI_PORT:-8080}"
ENABLE_DOWNLOADS_PERM_FIX="${ENABLE_DOWNLOADS_PERM_FIX:-false}"

# Reconfigure abc user/group to match PUID/PGID at runtime.
if [ "$(id -g abc)" != "$PGID" ]; then
    groupmod -o -g "$PGID" abc
fi
if [ "$(id -u abc)" != "$PUID" ]; then
    usermod -o -u "$PUID" abc
fi

# /config is small (qBT state), always chown -R.
chown -R abc:abc /config

# /downloads is typically large (TB scale on NAS). Recursive chown is
# opt-in via ENABLE_DOWNLOADS_PERM_FIX=true. By default we only chown the
# mountpoint itself so qBT can write into it; existing files are left alone.
if [ "$ENABLE_DOWNLOADS_PERM_FIX" = "true" ]; then
    chown -R abc:abc /downloads
else
    chown abc:abc /downloads
fi

umask "$UMASK"

exec su-exec abc:abc qbittorrent-nox \
    --webui-port="$WEBUI_PORT" \
    --profile=/config \
    "$@"
