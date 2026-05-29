#!/usr/bin/env bash
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SRC_DIR/haproxy.sh"
INSTALL_DIR="/opt/haproxy-menu"
INSTALL_FILE="$INSTALL_DIR/haproxy.sh"
SHORTCUT_MAIN="/usr/local/bin/haproxy-menu"
SHORTCUT_SHORT="/usr/local/bin/hapmenu"

if [ "$(id -u)" != "0" ]; then
  echo "Run as root: sudo bash force-install.sh"
  exit 1
fi

if [ ! -f "$SRC" ]; then
  echo "haproxy.sh not found next to force-install.sh"
  exit 1
fi

if ! grep -q '^APP_VERSION="2.6"' "$SRC"; then
  echo "This is not haproxy.sh v2.6:"
  grep -m1 '^APP_VERSION=' "$SRC" || true
  exit 1
fi

mkdir -p "$INSTALL_DIR"
install -m 755 "$SRC" "$INSTALL_FILE"
rm -f "$SHORTCUT_MAIN" "$SHORTCUT_SHORT"
ln -s "$INSTALL_FILE" "$SHORTCUT_MAIN"
ln -s "$INSTALL_FILE" "$SHORTCUT_SHORT"
hash -r 2>/dev/null || true

echo "Installed:"
grep -m1 '^APP_VERSION=' "$INSTALL_FILE"
echo "hapmenu path: $(command -v hapmenu || true)"
"$SHORTCUT_SHORT" --version
