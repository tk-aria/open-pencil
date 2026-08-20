# Browser sidecar for openpencil-mcp: keeps a Chromium tab open against the
# MCP server's web UI so /ws registers a browser and design-operation tools work.
#
# Runs as a separate container from the MCP server image on purpose (responsibility
# split — MCP server updates independently of the browser/VNC stack).
#
# arm64-first: uses Debian's "chromium" package (multi-arch) instead of
# google-chrome-stable (amd64-only .deb from Google's repo).
#
# Build (local test, native arch of the docker daemon):
#   docker build -t openpencil-browser-sidecar:local docker/browser-sidecar
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:99 \
    SCREEN_WIDTH=1920 \
    SCREEN_HEIGHT=1080 \
    SCREEN_DEPTH=24 \
    VNC_PORT=5900 \
    NOVNC_PORT=6080 \
    OPENPENCIL_URL=http://localhost:7600/ \
    CHROME_PROFILE_DIR=/data/chrome-profile \
    CHROME_FLAGS=""

RUN apt-get update && apt-get install -y --no-install-recommends \
    xvfb \
    x11vnc \
    openbox \
    novnc \
    websockify \
    chromium \
    fonts-noto-cjk \
    fonts-liberation \
    ca-certificates \
    curl \
    procps \
    supervisor \
    dbus-x11 \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash chrome \
    && mkdir -p /data/chrome-profile /var/log/supervisor \
    && chown -R chrome:chrome /data /home/chrome

COPY entrypoint.sh /entrypoint.sh
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
RUN chmod +x /entrypoint.sh

# 5900: VNC direct / 6080: noVNC web UI
EXPOSE 5900 6080

WORKDIR /home/chrome
ENTRYPOINT ["/entrypoint.sh"]
