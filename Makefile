# Shortcuts for everyday tasks. Run `make help` for the full list.

# Sidecar container tuned by `make tune-sidecar`.
CONTAINER ?= vm-ubuntu

.PHONY: desktop status ubuntu debian arch fedora alpine tune tune-sidecar kali stop-all logs help

desktop: ## Restart the Plasma desktop and noVNC bridge on port 6080
	bash .devcontainer/start-vnc.sh

status: ## Show desktop health and access URLs
	bash scripts/status.sh

ubuntu: ## Boot the Ubuntu Plasma sidecar on port 3001
	bash scripts/launch-distro.sh run ubuntu

debian: ## Boot the Debian Plasma sidecar on port 3002
	bash scripts/launch-distro.sh run debian

arch: ## Boot the Arch Plasma sidecar on port 3003
	bash scripts/launch-distro.sh run arch

fedora: ## Boot the Fedora Plasma sidecar on port 3004
	bash scripts/launch-distro.sh run fedora

alpine: ## Boot the Alpine Plasma sidecar on port 3005
	bash scripts/launch-distro.sh run alpine

tune: ## Apply the tuned profile to the main desktop
	bash scripts/tune-kde.sh

tune-sidecar: ## Apply the tuned profile to a sidecar (CONTAINER=vm-arch)
	bash scripts/tune-kde.sh --container $(CONTAINER)

kali: ## Boot the Kali Linux VNC desktop on port 3006 (large download)
	docker rm -f vm-kali 2>/dev/null || true
	docker run -d --name vm-kali --privileged -p 3006:6080 --shm-size=2gb --restart unless-stopped dorowu/kali-linux-vnc:latest
	@echo "Kali → open forwarded port 3006 (credentials: see image docs / docker logs vm-kali)"

stop-all: ## Stop all sidecar containers
	bash scripts/launch-distro.sh stop-all

logs: ## Follow the main desktop logs
	tail -n 50 -F /tmp/vncserver.log /tmp/novnc.log

help: ## List available targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS=":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'
