#!/usr/bin/env bash
#
# launch-distro.sh
#
# Boots additional Linux distributions as KDE Plasma desktop containers
# using the maintained linuxserver/webtop images. Each container serves
# its desktop over HTTP, which Codespaces forwards to the browser.
#
# Available: Ubuntu, Debian, Arch, Fedora and Alpine on ports 3001-3005.
#
# Usage:
#   ./scripts/launch-distro.sh list
#   ./scripts/launch-distro.sh run ubuntu [port]
#   ./scripts/launch-distro.sh stop ubuntu
#   ./scripts/launch-distro.sh logs ubuntu
#   ./scripts/launch-distro.sh shell ubuntu
#   ./scripts/launch-distro.sh ps | stop-all | pull-all
set -euo pipefail

# Maps each name to its container image and default port.
declare -A DISTROS=(
  [ubuntu]="lscr.io/linuxserver/webtop:ubuntu-kde|3001"
  [debian]="lscr.io/linuxserver/webtop:debian-kde|3002"
  [arch]="lscr.io/linuxserver/webtop:arch-kde|3003"
  [fedora]="lscr.io/linuxserver/webtop:fedora-kde|3004"
  [alpine]="lscr.io/linuxserver/webtop:alpine-kde|3005"
)

# Sidecar data lives here by default. Point VM_CONFIG_ROOT at /workspaces
# to keep sidecar data in persistent storage.
VOLUME_ROOT="${VM_CONFIG_ROOT:-/tmp}"
SHM_SIZE="${VM_SHM_SIZE:-2gb}"
TZ="${TZ:-Etc/UTC}"

cname() { echo "vm-$1"; }

url_for() {
  local port="$1"
  if [ -n "${CODESPACE_NAME:-}" ] && [ -n "${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-}" ]; then
    echo "https://${CODESPACE_NAME}-${port}.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}/"
  else
    echo "http://localhost:${port}/"
  fi
}

need_docker() {
  if ! command -v docker >/dev/null 2>&1; then echo "docker CLI not found. Rebuild codespace (docker-in-docker feature)."; exit 1; fi
  if ! docker info >/dev/null 2>&1; then echo "docker daemon not ready yet — wait ~30s and retry."; exit 1; fi
}

cmd_list() {
  echo "KDE Plasma sidecars:"
  for d in ubuntu debian arch fedora alpine; do
    IFS='|' read -r img port <<< "${DISTROS[$d]}"
    printf '  %-8s → %-45s default port %s\n' "$d" "$img" "$port"
  done
  echo ""
  echo "Tune a running sidecar:  bash scripts/tune-kde.sh --container vm-ubuntu"
  echo ""
  echo "CLI-only one-liners (no desktop, instant):"
  echo "  docker run -it --rm ubuntu:24.04 bash"
  echo "  docker run -it --rm archlinux:latest bash"
  echo "  docker run -it --rm fedora:latest bash"
  echo "  docker run -it --rm kalilinux/kali-rolling bash"
}

cmd_run() {
  need_docker
  local distro="${1:-}"; local port="${2:-}"
  if [ -z "$distro" ] || [ -z "${DISTROS[$distro]:-}" ]; then echo "Unknown distro '$distro'."; cmd_list; exit 1; fi
  IFS='|' read -r img default_port <<< "${DISTROS[$distro]}"
  port="${port:-$default_port}"
  local name; name="$(cname "$distro")"

  if docker ps -a --format '{{.Names}}' | grep -qx "$name"; then
    echo "Container $name exists — restarting on port $port..."
    docker rm -f "$name" >/dev/null
  fi

  echo "Pulling $img (first run downloads ~500MB-1GB)..."
  docker pull "$img"

  local cfg="$VOLUME_ROOT/${name}-config"
  mkdir -p "$cfg"
  echo "Starting $name on port $port (config: $cfg)..."
  docker run -d \
    --name "$name" \
    --privileged \
    -e PUID="$(id -u)" -e PGID="$(id -g)" \
    -e TZ="$TZ" \
    -p "${port}:3000" \
    -v "$cfg:/config" \
    --shm-size="$SHM_SIZE" \
    --restart unless-stopped \
    "$img" >/dev/null

  sleep 3
  echo ""
  echo "✅ $distro desktop is starting!"
  echo "   🌐 Open: $(url_for "$port")"
  echo "   (Codespaces: PORTS tab → globe icon on $port. First load takes ~10-20s.)"
  echo "   ✨ Tune it: bash scripts/tune-kde.sh --container $name"
  echo "   🐚 Shell: ./scripts/launch-distro.sh shell $distro"
  echo "   🛑 Stop:  ./scripts/launch-distro.sh stop $distro"
}

cmd_stop()     { need_docker; docker rm -f "$(cname "${1:?usage: stop <distro>}")" && echo "stopped."; }
cmd_logs()     { need_docker; docker logs -f "$(cname "${1:?usage: logs <distro>}")"; }
cmd_shell()    { need_docker; docker exec -it "$(cname "${1:?usage: shell <distro>}")" /bin/bash -c 'bash || sh'; }
cmd_ps()       { need_docker; docker ps --filter 'name=vm-' --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}\t{{.Status}}'; }
cmd_stop_all() { need_docker; docker ps -q --filter 'name=vm-' | xargs -r docker rm -f; echo "all vm-* stopped."; }
cmd_pull_all() { need_docker; for d in "${!DISTROS[@]}"; do IFS='|' read -r img _ <<< "${DISTROS[$d]}"; docker pull "$img"; done; }

case "${1:-list}" in
  list)     cmd_list ;;
  run)      shift; cmd_run "$@" ;;
  stop)     shift; cmd_stop "$@" ;;
  logs)     shift; cmd_logs "$@" ;;
  shell|exec) shift; cmd_shell "$@" ;;
  ps)       cmd_ps ;;
  stop-all) cmd_stop_all ;;
  pull-all) cmd_pull_all ;;
  *) echo "usage: $0 {list|run|stop|logs|shell|ps|stop-all|pull-all}"; exit 1 ;;
esac
