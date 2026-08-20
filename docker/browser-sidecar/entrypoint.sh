#!/bin/bash
set -e

CHROME_PROFILE_DIR=${CHROME_PROFILE_DIR:-/data/chrome-profile}

echo "=== openpencil browser sidecar starting ==="
echo "OPENPENCIL_URL:     ${OPENPENCIL_URL:-http://localhost:7600/}"
echo "Chrome profile dir: ${CHROME_PROFILE_DIR}"
echo "noVNC:              http://0.0.0.0:${NOVNC_PORT:-6080}/vnc.html"

mkdir -p "$CHROME_PROFILE_DIR"

# プロファイルは PVC 上に永続化されるため、Pod が再作成されると前 Pod の
# Singleton ロックが残り Chromium が起動できなくなる
# （"The profile appears to be in use by another Chromium process ... on another computer"）。
# 起動時に必ず削除する。ロックを持っていたプロセスは Pod ごと消えているので安全。
rm -f "$CHROME_PROFILE_DIR"/Singleton{Lock,Socket,Cookie} 2>/dev/null || true

chown -R chrome:chrome "$CHROME_PROFILE_DIR"

exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf
