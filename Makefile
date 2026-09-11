# Shortcuts for everyday tasks. Run `make help` for the full list.

.PHONY: desktop status ubuntu debian arch fedora alpine kde kde-debian kde-arch kde-fedora kde-alpine tune-kde tune-kde-webtop switch-kde switch-xfce kali stop-all logs help

desktop: ## Restart the main desktop and noVNC bridge on port 6080
	bash .devcontainer/start-vnc.sh

status: ## Show desktop health and access URLs
	bash scripts/status.sh

ubuntu: ## Boot the Ubuntu XFCE sidecar on port 3001
	bash scripts/launch-distro.sh run ubuntu

debian: ## Boot the Debian XFCE sidecar on port 3002
	bash scripts/launch-distro.sh run debian

arch: ## Boot the Arch XFCE sidecar on port 3003
	bash scripts/launch-distro.sh run arch

fedora: ## Boot the Fedora XFCE sidecar on port 3004
	bash scripts/launch-distro.sh run fedora

alpine: ## Boot the Alpine XFCE sidecar on port 3005
	bash scripts/launch-distro.sh run alpine

kde: ## Boot the Ubuntu KDE Plasma sidecar on port 3006
	bash scripts/launch-distro.sh run ubuntu-kde

kde-debian: ## Boot the Debian KDE Plasma sidecar on port 3007
	bash scripts/launch-distro.sh run debian-kde

kde-arch: ## Boot the Arch KDE Plasma sidecar on port 3008
	bash scripts/launch-distro.sh run arch-kde

kde-fedora: ## Boot the Fedora KDE Plasma sidecar on port 3009
	bash scripts/launch-distro.sh run fedora-kde

kde-alpine: ## Boot the Alpine KDE Plasma sidecar on port 3010
	bash scripts/launch-distro.sh run alpine-kde

tune-kde: ## Apply the tuned KDE profile to the main desktop
	bash scripts/tune-kde.sh

tune-kde-webtop: ## Apply the tuned KDE profile to the ubuntu-kde sidecar
	bash scripts/tune-kde.sh --container vm-ubuntu-kde

switch-kde: ## Install Plasma on the main desktop and switch to it (needs sudo)
	sudo bash scripts/switch-desktop.sh kde

switch-xfce: ## Switch the main desktop back to XFCE (needs sudo)
	sudo bash scripts/switch-desktop.sh xfce

kali: ## Boot the Kali Linux VNC desktop on port 3011 (large download)
	docker rm -f vm-kali 2>/dev/null || true
	docker run -d --name vm-kali --privileged -p 3011:6080 --shm-size=2gb --restart unless-stopped dorowu/kali-linux-vnc:latest
	@echo "Kali → open forwarded port 3011 (credentials: see image docs / docker logs vm-kali)"

stop-all: ## Stop all sidecar containers
	bash scripts/launch-distro.sh stop-all

logs: ## Follow the main desktop logs
	tail -n 50 -F /tmp/vncserver.log /tmp/novnc.log

help: ## List available targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS=":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'
