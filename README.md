# Codespace VM

Run full Linux desktops in your browser, powered entirely by GitHub Codespaces.

Codespace VM turns a Codespace into a personal Linux lab: a persistent Ubuntu
desktop streamed over noVNC, with one-command sidecar containers for Ubuntu,
Debian, Arch, Fedora and Alpine in both XFCE and KDE Plasma flavors.

## Features

- Persistent Ubuntu desktop (XFCE or KDE Plasma) streamed to the browser via noVNC
- Ten on-demand distro containers: five distributions times two desktop environments
- Automatic startup, health checks and printed access URLs
- Tuned KDE profile: dark theme, compositor disabled for VNC performance, no file indexing
- Everything configurable through environment variables: password, resolution, desktop

## Requirements

- A GitHub account with Codespaces access
- 2-core machine for the main desktop; 4-core recommended when running sidecars

## Quickstart

1. Use this template (or fork it) to create your own repository.
2. Click Code, then Codespaces, then Create codespace on main.
3. Wait for the build to finish (2-4 minutes on first run). The desktop starts automatically.
4. In the PORTS panel, open port 6080 to launch the desktop. Default password: `vscode`.

Verify from the terminal:

```bash
./scripts/status.sh
```

## Access

| Desktop | Port | Address |
| --- | --- | --- |
| Main desktop (noVNC) | 6080 | `https://<codespace>-6080.app.github.dev/vnc.html` |
| Main desktop (native VNC client) | 5901 | Forward the port, then connect to `localhost:5901` |
| Ubuntu, Debian, Arch, Fedora, Alpine (XFCE) | 3001-3005 | `https://<codespace>-<port>.app.github.dev/` |
| Ubuntu, Debian, Arch, Fedora, Alpine (KDE) | 3006-3010 | `https://<codespace>-<port>.app.github.dev/` |
| Kali Linux (VNC) | 3011 | `https://<codespace>-3011.app.github.dev/` |

Ports are private by default, meaning only your GitHub account can open them.
Keep them that way.

## Running additional distros

```bash
./scripts/launch-distro.sh list            # show every available flavor
./scripts/launch-distro.sh run ubuntu      # XFCE on port 3001
./scripts/launch-distro.sh run arch-kde    # KDE Plasma on port 3008
./scripts/launch-distro.sh stop arch-kde
./scripts/launch-distro.sh stop-all
```

Shortcuts are also available through the Makefile (`make ubuntu`, `make kde-arch`,
and so on). Run `make help` for the full list.

## KDE Plasma

Three options, depending on how you want to run Plasma.

Switch the main desktop, with no rebuild required:

```bash
sudo bash scripts/switch-desktop.sh kde     # install, tune and switch to Plasma
sudo bash scripts/switch-desktop.sh xfce    # switch back to XFCE
```

The selection persists across Codespace restarts.

Start from the KDE image instead: when creating the Codespace, choose the
"Linux VM (KDE Plasma + noVNC)" configuration.

Run Plasma alongside XFCE: boot any `-kde` sidecar as shown above, then
optionally tune it:

```bash
bash scripts/tune-kde.sh --container vm-ubuntu-kde
```

The tuning profile enables the Breeze Dark theme, disables the KWin compositor
and desktop effects for VNC performance, disables Baloo file indexing and
automatic suspend, and applies a set of sensible workspace defaults. See
`scripts/tune-kde.sh` for the complete list.

## Configuration

| Variable | Default | Description |
| --- | --- | --- |
| VNC_PASSWORD | vscode | Password for VNC and noVNC access |
| RESOLUTION | 1280x800 | Desktop resolution (for example 1600x900, 1920x1080) |
| DESKTOP | xfce | Main desktop: `xfce` or `kde` |
| VNC_DISPLAY | :1 | VNC display number |

Apply changes by restarting the desktop:

```bash
VNC_PASSWORD='new-password' RESOLUTION=1920x1080 bash .devcontainer/start-vnc.sh
```

For persistent values, use Codespaces Secrets or export the variables in `~/.bashrc`.

## Resources

This project requests 10 GB of RAM (see `hostRequirements` in `devcontainer.json`).
GitHub provisions the smallest machine type that satisfies the request. The main
desktop alone runs comfortably within this; choose a 4-core machine when running
KDE or multiple sidecar containers.

Sidecar containers default to a 2 GB shared-memory allocation, adjustable
through `VM_SHM_SIZE`.

## Project structure

```text
.devcontainer/
    devcontainer.json        Codespace definition: image, ports, autostart
    Dockerfile               Main image: Ubuntu, XFCE, TigerVNC, noVNC, Firefox
    Dockerfile.kde           Variant image with KDE Plasma
    kde/devcontainer.json    Alternate configuration booting straight into Plasma
    start-vnc.sh             Starts the VNC server and the noVNC bridge
    xstartup, xstartup-kde   Session startup scripts for XFCE and Plasma
scripts/
    install-desktop.sh       Installs the desktop on a live Codespace (no rebuild)
    launch-distro.sh         Boots and manages sidecar distro containers
    tune-kde.sh              Applies the tuned Plasma profile
    switch-desktop.sh        Switches the main desktop between XFCE and Plasma
    status.sh                Health check; prints every desktop URL
docker-compose.yml           Boots multiple sidecars at once
Makefile                     Shortcuts for common tasks
```

## Common tasks

```bash
bash .devcontainer/start-vnc.sh   # restart the main desktop
./scripts/status.sh               # show status and URLs
tail -n 50 /tmp/vncserver.log     # VNC server log
tail -n 50 /tmp/novnc.log         # noVNC bridge log
```

Minimal CLI-only containers without a desktop:

```bash
docker run -it --rm ubuntu:24.04 bash
docker run -it --rm archlinux:latest bash
docker run -it --rm fedora:latest bash
docker run -it --rm kalilinux/kali-rolling bash
```

Kali with a desktop (large download):

```bash
docker run -d --name vm-kali -p 3011:6080 dorowu/kali-linux-vnc:latest
# then open port 3011
```

Copy files between the Codespace and a sidecar:

```bash
docker cp ./file.txt vm-ubuntu:/config/
docker cp vm-ubuntu:/config/output.txt ./
```

## Troubleshooting

| Symptom | Solution |
| --- | --- |
| Port 6080 refuses connections | The desktop is still starting, or it stopped. Run `bash .devcontainer/start-vnc.sh` and check `/tmp/vncserver.log` and `/tmp/novnc.log`. |
| Grey or black screen in the browser | The session script failed. Inspect `~/.vnc/*.log`, then run `vncserver -kill :1` and restart. |
| Authentication failed | The default password is `vscode`. Reset it with `VNC_PASSWORD=vscode bash .devcontainer/start-vnc.sh`. |
| `docker: permission denied` | Run `newgrp docker`, or rebuild the Codespace so the docker-in-docker feature applies. |
| Sidecar exits immediately | Usually out of memory. Stop other containers or use a larger machine, then check `docker logs <name>`. |
| Sluggish desktop | Lower the resolution, close tabs inside the desktop browser, or move to a 4-core machine. |

Full reset of the main desktop:

```bash
vncserver -kill :1; pkill -f websockify; rm -f /tmp/.X1-lock /tmp/.X11-unix/X1
bash .devcontainer/start-vnc.sh
```

## Data persistence

- `/workspaces` persists across Codespace stops and starts.
- The main desktop home directory (`/home/vscode`) persists for the lifetime of the Codespace.
- Sidecar containers are ephemeral. Their `/config` volumes map to `/tmp/vm-*-config`
  by default; set `VM_CONFIG_ROOT=/workspaces/.vm-config` before launching to keep
  sidecar data in persistent storage.

## Security

- Change the default VNC password before doing anything sensitive.
- Keep forwarded ports private.
- Never commit secrets to the repository; use Codespaces Secrets.
- Stop the Codespace when finished (`gh codespace stop`) to avoid unnecessary billing.

## Costs

Codespaces bills for core-hours while running. The free plan includes a monthly
allowance (roughly 120 core-hours). Set an idle timeout under repository
Settings, then Codespaces, to stop machines automatically.

## License

MIT. The `linuxserver/webtop` container images carry their own licenses.
