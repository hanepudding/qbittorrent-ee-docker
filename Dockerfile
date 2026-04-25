# syntax=docker/dockerfile:1.7
ARG ALPINE_VERSION=3.22

# ---------------------------------------------------------------------------
# Stage 1: fetch & verify the upstream QBEE static nox binary
# ---------------------------------------------------------------------------
FROM alpine:${ALPINE_VERSION} AS fetcher

ARG QBEE_VERSION
ARG QBEE_SHA256
ARG QBEE_ARCH=x86_64-linux-musl

RUN apk add --no-cache curl unzip

WORKDIR /tmp
RUN set -eux; \
    if [ -z "$QBEE_VERSION" ]; then echo "QBEE_VERSION must be set"; exit 1; fi; \
    if [ -z "$QBEE_SHA256" ]; then echo "QBEE_SHA256 must be set"; exit 1; fi; \
    URL="https://github.com/c0re100/qBittorrent-Enhanced-Edition/releases/download/release-${QBEE_VERSION}/qbittorrent-enhanced-nox_${QBEE_ARCH}_static.zip"; \
    echo "Fetching: $URL"; \
    curl -fsSL --retry 3 -o nox.zip "$URL"; \
    echo "${QBEE_SHA256}  nox.zip" | sha256sum -c -; \
    unzip nox.zip; \
    chmod +x qbittorrent-nox; \
    ./qbittorrent-nox --version

# ---------------------------------------------------------------------------
# Stage 2: final runtime image
# ---------------------------------------------------------------------------
FROM alpine:${ALPINE_VERSION}

ARG QBEE_VERSION

LABEL org.opencontainers.image.title="qBittorrent Enhanced Edition" \
      org.opencontainers.image.description="Minimal Docker packaging of c0re100/qBittorrent-Enhanced-Edition" \
      org.opencontainers.image.source="https://github.com/hanepudding/qbittorrent-ee-docker" \
      org.opencontainers.image.url="https://github.com/c0re100/qBittorrent-Enhanced-Edition" \
      org.opencontainers.image.version="${QBEE_VERSION}" \
      org.opencontainers.image.licenses="GPL-2.0-or-later"

ENV PUID=1000 \
    PGID=1000 \
    UMASK=022 \
    TZ=UTC \
    WEBUI_PORT=8080

RUN apk add --no-cache \
        bash \
        ca-certificates \
        python3 \
        shadow \
        su-exec \
        tini \
        tzdata && \
    addgroup -g 1000 abc && \
    adduser -D -u 1000 -G abc -h /config -s /sbin/nologin abc && \
    mkdir -p /config /downloads && \
    chown abc:abc /config /downloads

COPY --from=fetcher /tmp/qbittorrent-nox /usr/local/bin/qbittorrent-nox
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8080 6881/tcp 6881/udp
VOLUME ["/config", "/downloads"]

ENTRYPOINT ["/sbin/tini", "--", "/entrypoint.sh"]
