#!/usr/bin/env bash
#
# status.sh
#
# Reports the health of the main desktop, the noVNC bridge and any running
# sidecar containers, and prints the URL of every available desktop.
set -uo pipefail

green() { printf '\033[0;32m%s\033[0m\n' "$*"; }
red()   { printf '\033[0;31m%s\033[0m\n' "$*"; }
dim()   { printf '\033[2m%s\033[0m\n' "$*"; }

# Builds the public Codespaces URL for a port, or a localhost URL elsewhere.
codespace_url() { # $1: port, $2: path
  local port="$1" path="${2:-}"
  if [ -n "${CODESPACE_NAME:-}" ] && [ -n "${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-}" ]; then
    echo "https://${CODESPACE_NAME}-${port}.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}${path}"
  else
    echo "http://localhost:${port}${path}"
  fi
}

echo "════════ Codespace VM status ════════"
echo ""

# Main desktop: VNC server and noVNC bridge.
if pgrep -f "Xvnc.*:1" >/dev/null 2>&1 || pgrep -f "Xtigervnc.*:1" >/dev/null 2>&1; then
  green "● TigerVNC :1 (5901)   RUNNING"
else
  red   "○ TigerVNC :1 (5901)   NOT RUNNING  → run: bash .devcontainer/start-vnc.sh"
fi

if pgrep -f "websockify.*6080" >/dev/null 2>&1; then
  green "● noVNC websockify (6080) RUNNING"
else
  red   "○ noVNC websockify (6080) NOT RUNNING → run: bash .devcontainer/start-vnc.sh"
fi

echo ""
echo "  Main desktop:  $(codespace_url 6080 /vnc.html)"
echo "  VNC native:    port 5901 (user: anyone, pass: \$VNC_PASSWORD, default 'vscode')"
echo ""

# Sidecar distro containers.
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  echo "── docker distros ──"
  if docker ps --format '{{.Names}} {{.Ports}} {{.Status}}' 2>/dev/null | grep -q .; then
    docker ps --format '  • {{.Names}}  {{.Ports}}  ({{.Status}})' | grep -E 'vm-|dream|webtop' || docker ps --format '  • {{.Names}}  {{.Ports}}  ({{.Status}})'
  else
    dim "  (no vm-* containers running — try: ./scripts/launch-distro.sh run ubuntu)"
  fi
  echo ""
  echo "  webtop xfce:   3001 ubuntu · 3002 debian · 3003 arch · 3004 fedora · 3005 alpine"
  echo "  webtop kde:    3006 ubuntu · 3007 debian · 3008 arch · 3009 fedora · 3010 alpine"
else
  dim "── docker: not available (docker-in-docker still starting? wait 30s and retry) ──"
fi

echo ""
dim "logs: /tmp/vncserver.log  /tmp/novnc.log  ~/.vnc/*.log"
echo "══════════════════════════════════"
