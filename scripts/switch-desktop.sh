#!/usr/bin/env bash
#
# switch-desktop.sh
#
# Installs (if needed) and activates the main Codespace desktop, either
# KDE Plasma or XFCE. The selection is stored in
# ~/.config/codespace-vm-desktop and honored automatically on every
# Codespace start.
#
# Usage:
#   sudo bash scripts/switch-desktop.sh kde
#   sudo bash scripts/switch-desktop.sh xfce
set -euo pipefail

TARGET="${1:-}"
case "$TARGET" in
  kde|plasma) TARGET="kde" ;;
  xfce)       TARGET="xfce" ;;
  *) echo "usage: sudo bash scripts/switch-desktop.sh {kde|xfce}"; exit 1 ;;
esac

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo bash scripts/switch-desktop.sh $TARGET"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
TARGET_USER="${SUDO_USER:-vscode}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
TARGET_HOME="${TARGET_HOME:-/home/vscode}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

as_user() { sudo -u "$TARGET_USER" -H env HOME="$TARGET_HOME" "$@"; }

if [ "$TARGET" = "kde" ]; then
  if command -v startplasma-x11 >/dev/null 2>&1; then
    echo "[switch] Plasma already installed — skipping apt."
  else
    echo "[switch] Installing KDE Plasma (minimal + tuned app set, ~1.5GB)..."
    apt-get update
    apt-get install -y --no-install-recommends \
      kde-plasma-desktop plasma-workspace kwin-x11 \
      konsole dolphin kate ark gwenview \
      breeze breeze-icon-theme \
      fonts-hack fonts-noto
    apt-get clean
  fi
  mkdir -p /etc/codespace-vm
  if [ -f "$REPO_ROOT/.devcontainer/xstartup-kde" ]; then
    cp -f "$REPO_ROOT/.devcontainer/xstartup-kde" /etc/codespace-vm/xstartup-kde
  fi
  echo "[switch] Applying tuned KDE profile for $TARGET_USER ..."
  as_user bash "$REPO_ROOT/scripts/tune-kde.sh"
else
  if command -v startxfce4 >/dev/null 2>&1; then
    echo "[switch] XFCE already installed — skipping apt."
  else
    echo "[switch] Installing XFCE..."
    apt-get update
    apt-get install -y --no-install-recommends \
      xfce4 xfce4-goodies xfce4-terminal thunar-archive-plugin dbus-x11
    apt-get clean
  fi
fi

# Persist the choice. start-vnc.sh reads this file on every start;
# DESKTOP_FORCE=... overrides it for a single run.
as_user mkdir -p "$TARGET_HOME/.config"
printf '%s' "$TARGET" | as_user tee "$TARGET_HOME/.config/codespace-vm-desktop" >/dev/null
echo "[switch] Choice persisted ($TARGET). Restarting desktop..."

as_user bash "$REPO_ROOT/.devcontainer/start-vnc.sh"
