#!/usr/bin/env bash
#
# start-vnc.sh
#
# Starts the browser-accessible KDE Plasma desktop: a TigerVNC server for
# the desktop session and a noVNC (websockify) bridge on port 6080.
#
# Idempotent: existing sessions are stopped first, so this script can run
# any number of times, including automatically on every Codespace start.
#
# Environment:
#   VNC_PASSWORD   Password for VNC and noVNC access (default: vscode)
#   RESOLUTION     Desktop resolution, e.g. 1600x900 (default: 1600x900)
#   VNC_DISPLAY    VNC display number (default: :1)
set -euo pipefail

VNC_PASSWORD="${VNC_PASSWORD:-vscode}"
RESOLUTION="${RESOLUTION:-1600x900}"
DISPLAY_NUM="${VNC_DISPLAY:-:1}"
VNC_PORT=5901
NOVNC_PORT=6080
NOVNC_PATH="${NOVNC_PATH:-/usr/share/novnc}"
VNC_DIR="$HOME/.vnc"
LOG_VNC="/tmp/vncserver.log"
LOG_NOVNC="/tmp/novnc.log"

log() { echo "[start-vnc] $*"; }

# Verify the VNC stack and Plasma session are installed before touching
# any running sessions.
if ! command -v vncserver >/dev/null 2>&1; then
  log "ERROR: vncserver not installed. Run: sudo bash scripts/install-desktop.sh"
  exit 1
fi
if ! command -v startplasma-x11 >/dev/null 2>&1; then
  log "ERROR: KDE Plasma not installed. Run: sudo bash scripts/install-desktop.sh"
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

# Install the Plasma session script, preferring the copy on the system.
INSTALLED_XSTARTUP="/etc/codespace-vm/xstartup"
if [ -f "$INSTALLED_XSTARTUP" ]; then
  cp -f "$INSTALLED_XSTARTUP" "$VNC_DIR/xstartup"
elif [ -f "$(pwd)/.devcontainer/xstartup" ]; then
  cp -f "$(pwd)/.devcontainer/xstartup" "$VNC_DIR/xstartup"
elif [ ! -f "$VNC_DIR/xstartup" ]; then
  log "xstartup not found, writing embedded fallback..."
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
export XDG_SESSION_TYPE=x11 DESKTOP_SESSION=plasma XDG_CURRENT_DESKTOP=KDE
xset s off 2>/dev/null || true
xset -dpms 2>/dev/null || true
exec /usr/bin/startplasma-x11
EOF
fi
chmod +x "$VNC_DIR/xstartup"

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
if ! vncserver "$DISPLAY_NUM" \
  -geometry "$RESOLUTION" \
  -depth 24 \
  -localhost no \
  -rfbport "$VNC_PORT" \
  >>"$LOG_VNC" 2>&1; then
  log "ERROR: the VNC server failed to start. Last lines of $LOG_VNC:"
  tail -n 25 "$LOG_VNC" || true
  log "X session logs in $VNC_DIR:"
  tail -n 25 "$VNC_DIR"/*.log 2>/dev/null || true
  exit 1
fi

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
log "✅ Desktop is UP (KDE Plasma) — resolution $RESOLUTION"
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
