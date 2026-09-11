#!/usr/bin/env bash
#
# start-vnc.sh
#
# Starts the browser-accessible desktop: a TigerVNC server for the desktop
# session and a noVNC (websockify) bridge on port 6080.
#
# Idempotent: existing sessions are stopped first, so this script can run
# any number of times, including automatically on every Codespace start.
#
# Environment:
#   VNC_PASSWORD   Password for VNC and noVNC access (default: vscode)
#   RESOLUTION     Desktop resolution, e.g. 1280x800 (default: 1280x800)
#   VNC_DISPLAY    VNC display number (default: :1)
#   DESKTOP        Desktop session to start: xfce or kde (default: xfce)
#   DESKTOP_FORCE  One-off override of the persisted desktop choice
set -euo pipefail

VNC_PASSWORD="${VNC_PASSWORD:-vscode}"
RESOLUTION="${RESOLUTION:-1280x800}"
DISPLAY_NUM="${VNC_DISPLAY:-:1}"
DESKTOP="${DESKTOP:-xfce}"
VNC_PORT=5901
NOVNC_PORT=6080
NOVNC_PATH="${NOVNC_PATH:-/usr/share/novnc}"
VNC_DIR="$HOME/.vnc"
PERSISTED_DESKTOP_FILE="$HOME/.config/codespace-vm-desktop"
LOG_VNC="/tmp/vncserver.log"
LOG_NOVNC="/tmp/novnc.log"

log() { echo "[start-vnc] $*"; }

# Resolve which desktop to start.
# Precedence: DESKTOP_FORCE, then the persisted choice written by
# switch-desktop.sh, then the DESKTOP environment variable.
if [ -n "${DESKTOP_FORCE:-}" ]; then
  DESKTOP="$DESKTOP_FORCE"
elif [ -f "$PERSISTED_DESKTOP_FILE" ]; then
  DESKTOP="$(tr -d ' \t\n\r' < "$PERSISTED_DESKTOP_FILE")"
fi

# Verify the VNC stack is installed before touching any running sessions.
if ! command -v vncserver >/dev/null 2>&1; then
  log "ERROR: vncserver not installed. Run: sudo bash scripts/install-desktop.sh"
  exit 1
fi
if [ ! -f "$NOVNC_PATH/vnc.html" ]; then
  if [ -f "$NOVNC_PATH/index.html" ]; then
    log "note: vnc.html missing, index.html present — fine."
  else
    log "ERROR: noVNC web files not found at $NOVNC_PATH"
    exit 1
  fi
fi
if ! command -v websockify >/dev/null 2>&1; then
  log "ERROR: websockify not installed. Run: sudo bash scripts/install-desktop.sh"
  exit 1
fi

mkdir -p "$VNC_DIR"

# Store the VNC password in the format TigerVNC expects.
printf '%s' "$VNC_PASSWORD" | vncpasswd -f > "$VNC_DIR/passwd"
chmod 600 "$VNC_DIR/passwd"
log "VNC password set (${#VNC_PASSWORD} chars)."

# Locate a session script, preferring the copy installed on the system.
find_repo_file() { # $1: filename under .devcontainer/
  for c in "/etc/codespace-vm/$1" \
           "$(pwd)/.devcontainer/$1" \
           "$HOME/codespace-vm/.devcontainer/$1"; do
    if [ -f "$c" ]; then echo "$c"; return 0; fi
  done
  return 1
}

# Select the session startup script for the requested desktop.
case "$DESKTOP" in
  kde|plasma)
    DESKTOP="kde"
    if ! command -v startplasma-x11 >/dev/null 2>&1; then
      log "ERROR: DESKTOP=kde but Plasma isn't installed."
      log "  Install it live:  sudo bash scripts/switch-desktop.sh kde"
      log "  Or rebuild with:  .devcontainer/kde/devcontainer.json"
      exit 1
    fi
    if SRC="$(find_repo_file xstartup-kde)"; then
      cp -f "$SRC" "$VNC_DIR/xstartup"
    else
      log "xstartup-kde not found, writing embedded fallback..."
      cat > "$VNC_DIR/xstartup" <<'EOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
[ -r "$HOME/.Xresources" ] && xrdb "$HOME/.Xresources"
xsetroot -solid "#232629" 2>/dev/null || true
vncconfig -iconic 2>/dev/null &
if command -v dbus-launch >/dev/null 2>&1; then
  eval "$(dbus-launch --sh-syntax --exit-with-session)"
fi
export XDG_SESSION_TYPE=x11 DESKTOP_SESSION=plasma XDG_CURRENT_DESKTOP=KDE KDE_SESSION_VERSION=5
xset s off 2>/dev/null || true
xset -dpms 2>/dev/null || true
exec /usr/bin/startplasma-x11
EOF
    fi
    # Keep KWin compositing disabled so Plasma stays responsive over VNC.
    # Applied here as a safeguard even if tune-kde.sh has never run.
    if command -v python3 >/dev/null 2>&1; then
      mkdir -p "$HOME/.config"
      python3 -c "
import configparser, os
p = os.path.expanduser('~/.config/kwinrc')
c = configparser.ConfigParser(); c.optionxform = str
if os.path.exists(p):
    try: c.read(p)
    except Exception: pass
if not c.has_section('Compositing'): c.add_section('Compositing')
c.set('Compositing', 'Enabled', 'false')
c.set('Compositing', 'AnimationSpeed', '3')
with open(p, 'w') as f: c.write(f)
" 2>/dev/null || true
    fi
    ;;
  *)
    DESKTOP="xfce"
    if ! command -v startxfce4 >/dev/null 2>&1; then
      log "ERROR: XFCE isn't installed. Run: sudo bash scripts/install-desktop.sh"
      exit 1
    fi
    if SRC="$(find_repo_file xstartup)"; then
      cp -f "$SRC" "$VNC_DIR/xstartup"
    elif [ ! -f "$VNC_DIR/xstartup" ]; then
      cat > "$VNC_DIR/xstartup" <<'EOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
xsetroot -solid "#2C3E50" 2>/dev/null || true
vncconfig -iconic 2>/dev/null &
exec startxfce4
EOF
    fi
    ;;
esac
chmod +x "$VNC_DIR/xstartup"
log "Desktop session: $DESKTOP"

# Stop any stale sessions left over from a previous run.
log "cleaning stale VNC sessions..."
vncserver -kill "$DISPLAY_NUM" >>"$LOG_VNC" 2>&1 || true
pkill -f "websockify.*$NOVNC_PORT" 2>/dev/null || true
rm -f "/tmp/.X${DISPLAY_NUM#:}-lock" "/tmp/.X11-unix/X${DISPLAY_NUM#:}" 2>/dev/null || true
sleep 1

# Start the VNC server. Local connections are allowed so the noVNC bridge
# on this host can attach; external access arrives through Codespaces
# port forwarding.
log "starting TigerVNC $DISPLAY_NUM at $RESOLUTION ..."
vncserver "$DISPLAY_NUM" \
  -geometry "$RESOLUTION" \
  -depth 24 \
  -localhost no \
  -rfbport "$VNC_PORT" \
  >>"$LOG_VNC" 2>&1

sleep 2

# Bridge the VNC server to the browser via noVNC.
log "starting noVNC on 0.0.0.0:$NOVNC_PORT -> localhost:$VNC_PORT ..."
nohup websockify \
  --web "$NOVNC_PATH" \
  "0.0.0.0:$NOVNC_PORT" \
  "localhost:$VNC_PORT" \
  >>"$LOG_NOVNC" 2>&1 &
WS_PID=$!
sleep 1

if kill -0 "$WS_PID" 2>/dev/null; then
  log "websockify running (pid $WS_PID)."
else
  log "ERROR: websockify died instantly. Tail of $LOG_NOVNC:"
  tail -n 30 "$LOG_NOVNC" || true
  exit 1
fi

echo ""
log "✅ Desktop is UP ($DESKTOP) — resolution $RESOLUTION"
log "   VNC password: $VNC_PASSWORD"
if [ -n "${CODESPACE_NAME:-}" ] && [ -n "${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-}" ]; then
  echo "   🌐 noVNC:  https://${CODESPACE_NAME}-${NOVNC_PORT}.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}/vnc.html"
  echo "   🔌 VNC:    forward port ${VNC_PORT}, then connect a VNC client to localhost:${VNC_PORT}"
else
  echo "   🌐 noVNC:  http://localhost:${NOVNC_PORT}/vnc.html"
  echo "   🔌 VNC:    localhost:${VNC_PORT}"
fi
echo "   📋 logs:   $LOG_VNC  $LOG_NOVNC"
echo ""
