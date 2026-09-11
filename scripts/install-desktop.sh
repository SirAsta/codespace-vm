#!/usr/bin/env bash
#
# install-desktop.sh
#
# Installs the KDE Plasma desktop and VNC stack on a running Codespace.
# Use this when working with an existing Codespace instead of rebuilding
# from this repository's dev container definitions.
#
# Supports Ubuntu, Debian, Arch and Fedora. The distribution is detected
# automatically and can be overridden with --distro. Must be run as root:
#   sudo bash scripts/install-desktop.sh [--distro ubuntu|debian|arch|fedora]
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run as root: sudo bash scripts/install-desktop.sh"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
TARGET_USER="${SUDO_USER:-vscode}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NOVNC_VERSION="1.5.0"
NOVNC_PATH="/opt/novnc"

# Detect the distribution from /etc/os-release (ID or ID_LIKE).
detect_distro() {
  local id="" like=""
  if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    id="${ID:-}"
    like="${ID_LIKE:-}"
  fi
  case " $id $like " in
    *" arch "*)   echo arch ;;
    *" fedora "*) echo fedora ;;
    *" debian "*) echo debian ;;
    *" ubuntu "*) echo ubuntu ;;
    *)            echo unknown ;;
  esac
}

DISTRO="auto"
if [ "${1:-}" = "--distro" ]; then
  DISTRO="${2:?usage: sudo bash scripts/install-desktop.sh [--distro ubuntu|debian|arch|fedora]}"
fi
if [ "$DISTRO" = "auto" ]; then
  DISTRO="$(detect_distro)"
fi
case "$DISTRO" in
  ubuntu|debian|arch|fedora) ;;
  *)
    echo "ERROR: unsupported distribution (detected: $DISTRO)."
    echo "Supported: Ubuntu, Debian, Arch, Fedora."
    exit 1
    ;;
esac
echo "[install] Distribution: $DISTRO (user: $TARGET_USER)"

# Installs the pinned noVNC web client and the websockify bridge.
# Used on every distro except Ubuntu, which ships both natively.
# A compatibility symlink keeps the default noVNC path working.
install_novnc_fallback() {
  echo "[install] Installing noVNC $NOVNC_VERSION + websockify..."
  rm -rf "$NOVNC_PATH" "/opt/noVNC-$NOVNC_VERSION"
  curl -fsSL "https://github.com/novnc/noVNC/archive/refs/tags/v${NOVNC_VERSION}.tar.gz" \
    | tar xzf - -C /opt
  mv "/opt/noVNC-$NOVNC_VERSION" "$NOVNC_PATH"
  ln -sfn "$NOVNC_PATH" /usr/share/novnc
  PIP_BREAK_SYSTEM_PACKAGES=1 python3 -m pip install --no-cache-dir -q websockify
}

echo "[install] Installing desktop packages (this takes several minutes)..."
case "$DISTRO" in
  ubuntu)
    apt-get update
    apt-get install -y --no-install-recommends \
      kde-plasma-desktop plasma-workspace kwin-x11 \
      konsole dolphin kate ark gwenview breeze breeze-icon-theme \
      dbus-x11 x11-utils x11-xserver-utils \
      xfonts-base fonts-dejavu fonts-liberation fonts-noto fonts-hack \
      tigervnc-standalone-server tigervnc-common \
      novnc websockify \
      supervisor firefox python3 \
      curl wget git vim nano htop net-tools ca-certificates tzdata locales unzip zip
    apt-get clean
    rm -rf /var/lib/apt/lists/*
    ;;
  debian)
    apt-get update
    apt-get install -y --no-install-recommends \
      kde-plasma-desktop plasma-workspace kwin-x11 \
      konsole dolphin kate ark gwenview breeze breeze-icon-theme \
      tigervnc-standalone-server tigervnc-common \
      firefox-esr dbus-x11 x11-utils x11-xserver-utils \
      fonts-dejavu fonts-liberation fonts-noto fonts-hack xfonts-base \
      git sudo python3 python3-pip procps curl wget vim nano htop tar gzip ca-certificates
    apt-get clean
    rm -rf /var/lib/apt/lists/*
    install_novnc_fallback
    ;;
  arch)
    pacman -Syu --noconfirm \
      plasma-desktop kwin konsole dolphin kate ark gwenview breeze breeze-icons \
      tigervnc firefox xorg-xsetroot xorg-xrdb xorg-xset dbus \
      ttf-dejavu ttf-liberation noto-fonts ttf-hack font-misc-misc font-alias \
      git sudo python python-pip procps-ng curl wget vim nano htop tar gzip
    pacman -Scc --noconfirm
    rm -rf /var/cache/pacman/pkg/*
    install_novnc_fallback
    ;;
  fedora)
    dnf install -y \
      plasma-desktop plasma-workspace plasma-workspace-x11 \
      konsole dolphin kate ark gwenview \
      tigervnc-server firefox xrdb xset xsetroot dbus-x11 \
      dejavu-sans-fonts dejavu-sans-mono-fonts \
      liberation-sans-fonts liberation-mono-fonts \
      google-noto-sans-fonts google-noto-sans-mono-fonts \
      xorg-x11-fonts-misc \
      git sudo python3 python3-pip procps-ng curl wget nano htop tar gzip bash
    dnf install -y breeze-icon-theme vim-enhanced || true
    dnf clean all
    rm -rf /var/cache/dnf
    install_novnc_fallback
    ;;
esac

# Fail fast if the remote-desktop toolchain is incomplete.
command -v vncserver >/dev/null || { echo "ERROR: vncserver missing after install"; exit 1; }
command -v startplasma-x11 >/dev/null || { echo "ERROR: startplasma-x11 missing after install"; exit 1; }
command -v websockify >/dev/null || { echo "ERROR: websockify missing after install"; exit 1; }

echo "[install] Installing session configuration for $TARGET_USER..."
mkdir -p /etc/codespace-vm
if [ -f "$REPO_ROOT/.devcontainer/xstartup" ]; then
  cp -f "$REPO_ROOT/.devcontainer/xstartup" /etc/codespace-vm/xstartup
fi
chmod +x /etc/codespace-vm/xstartup

echo "[install] Applying tuned Plasma profile for $TARGET_USER..."
sudo -u "$TARGET_USER" -H bash "$REPO_ROOT/scripts/tune-kde.sh"

echo "[install] Starting desktop as $TARGET_USER..."
sudo -u "$TARGET_USER" -H bash "$REPO_ROOT/.devcontainer/start-vnc.sh"

echo ""
echo "[install] Done. Run ./scripts/status.sh to see the desktop URL."
