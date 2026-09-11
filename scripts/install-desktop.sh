#!/usr/bin/env bash
#
# install-desktop.sh
#
# Installs the XFCE desktop and VNC stack on a running Codespace.
# Use this when working with an existing Codespace instead of rebuilding
# from this repository's dev container definition.
#
# Must be run as root:
#   sudo bash scripts/install-desktop.sh
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run as root: sudo bash scripts/install-desktop.sh"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
TARGET_USER="${SUDO_USER:-vscode}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
TARGET_HOME="${TARGET_HOME:-/home/vscode}"

echo "[install] Installing desktop packages (this takes 2-5 minutes)..."
apt-get update
apt-get install -y --no-install-recommends \
  xfce4 xfce4-goodies xfce4-terminal thunar-archive-plugin \
  dbus-x11 x11-utils x11-xserver-utils \
  xfonts-base fonts-dejavu fonts-liberation fonts-noto \
  tigervnc-standalone-server tigervnc-common \
  novnc websockify \
  supervisor firefox \
  curl wget git vim nano htop net-tools ca-certificates tzdata locales unzip zip
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "[install] Installing session configuration for $TARGET_USER..."
mkdir -p /etc/codespace-vm
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ -f "$REPO_ROOT/.devcontainer/xstartup" ]; then
  cp -f "$REPO_ROOT/.devcontainer/xstartup" /etc/codespace-vm/xstartup
fi
chmod +x /etc/codespace-vm/xstartup

echo "[install] Starting desktop as $TARGET_USER..."
sudo -u "$TARGET_USER" -H bash "$REPO_ROOT/.devcontainer/start-vnc.sh"

echo ""
echo "[install] Done. Run ./scripts/status.sh to see the desktop URL."
