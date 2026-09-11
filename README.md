# Codespace VM

Run a full KDE Plasma desktop in your browser, powered entirely by GitHub Codespaces.

Pick your Linux distribution when you create the Codespace — Ubuntu, Arch,
Fedora or Debian — and it boots straight into Plasma. No commands to run.

## Features

- Four distro images, each booting straight into KDE Plasma streamed over noVNC
- Tuned Plasma profile: dark theme, compositor disabled for VNC performance, no file indexing
- Automatic startup, health checks and printed access URLs
- Five on-demand Plasma sidecars on the Ubuntu configuration
- Everything configurable through environment variables: password, resolution, display

## Requirements

- A GitHub account with Codespaces access
- 4-core machine recommended (Plasma is heavier than minimal desktops); 10 GB of RAM requested

## Quickstart

1. Use this template (or fork it) to create your own repository.
2. In your repository, click Code, then the Codespaces tab, then the ellipsis
   (...) and "New with options".
3. Under "Dev container configuration", pick your distribution (default: Ubuntu).
4. Create the Codespace. The first build takes several minutes; the desktop
   starts automatically.
5. In the PORTS panel, open port 6080 to launch the desktop. Default password: `vscode`.

Verify from the terminal:

```bash
./scripts/status.sh
```

To make a different distro your default, copy its `devcontainer.json` over
`.devcontainer/devcontainer.json` (for example from `.devcontainer/arch/`).

## Available configurations

| Configuration | Base image | Docker sidecars? | Best for |
| --- | --- | --- | --- |
| Default (Ubuntu) | Ubuntu LTS | Yes — five Plasma sidecars plus Kali | Most users; the full lab |
| Arch Plasma | Arch Linux (rolling) | No | Latest packages and AUR-style tinkering |
| Fedora Plasma | Fedora (latest) | No | The Red Hat ecosystem |
| Debian Plasma | Debian (stable) | No | A minimal, stable base |

Sidecar containers need Docker, which is installed on the Ubuntu configuration
only. Alpine Linux is available as a sidecar there; it has no dev container
configuration of its own because its musl libc cannot run the VS Code server.

## Access

| Desktop | Port | Address |
| --- | --- | --- |
| Main desktop, KDE Plasma (noVNC) | 6080 | `https://<codespace>-6080.app.github.dev/vnc.html` |
| Main desktop (native VNC client) | 5901 | Forward the port, then connect to `localhost:5901` |
| Ubuntu, Debian, Arch, Fedora, Alpine (Plasma sidecars) | 3001-3005 | `https://<codespace>-<port>.app.github.dev/` |
| Kali Linux (VNC) | 3006 | `https://<codespace>-3006.app.github.dev/` |

Ports 3001-3006 exist on the Ubuntu configuration only. All ports are private
by default, meaning only your GitHub account can open them. Keep them that way.

## Tuning

Every desktop ships with a tuned Plasma profile (`scripts/tune-kde.sh`):

| Tweak | Why |
| --- | --- |
| KWin compositing and all desktop effects off, instant animations | Remote protocols cannot sustain composited rendering; this is the main VNC speedup |
| Breeze Dark theme, dark icons, Noto Sans and Hack fonts | Coherent dark UI out of the box |
| Baloo file indexing off, KRunner search trimmed | Saves memory and background CPU usage |
| Automatic suspend off | A sleeping cloud machine is just a frozen tab |
| Two virtual desktops, double-click, Konsole and Firefox defaults | Sensible workspace behavior |

Re-apply it to the main desktop at any time:

```bash
bash scripts/tune-kde.sh
```

Or tune a running sidecar (Ubuntu configuration):

```bash
bash scripts/tune-kde.sh --container vm-ubuntu
make tune-sidecar CONTAINER=vm-arch
```

## Running additional distros

Available on the Ubuntu configuration:

```bash
./scripts/launch-distro.sh list            # show every available sidecar
./scripts/launch-distro.sh run ubuntu      # Ubuntu Plasma on port 3001
./scripts/launch-distro.sh run arch        # Arch Plasma on port 3003
./scripts/launch-distro.sh stop arch
./scripts/launch-distro.sh stop-all
```

Shortcuts are also available through the Makefile (`make ubuntu`, `make arch`,
and so on). Run `make help` for the full list.

## Configuration

| Variable | Default | Description |
| --- | --- | --- |
| VNC_PASSWORD | vscode | Password for VNC and noVNC access |
| RESOLUTION | 1600x900 | Desktop resolution (for example 1280x800, 1920x1080) |
| VNC_DISPLAY | :1 | VNC display number |

Apply changes by restarting the desktop:

```bash
VNC_PASSWORD='new-password' RESOLUTION=1920x1080 bash .devcontainer/start-vnc.sh
```

For persistent values, use Codespaces Secrets or export the variables in `~/.bashrc`.

## Resources

Every configuration requests 4 CPUs and 10 GB of RAM (see `hostRequirements`).
GitHub provisions the smallest machine type that satisfies the request. The main
desktop alone runs comfortably within this; on the Ubuntu configuration, stop
sidecars you are not using to keep things responsive.

Sidecar containers default to a 2 GB shared-memory allocation, adjustable
through `VM_SHM_SIZE`.

## Project structure

```text
.devcontainer/
    devcontainer.json        Default (Ubuntu): image, ports, autostart, Docker
    Dockerfile               Ubuntu image: KDE Plasma, TigerVNC, noVNC, Firefox
    arch/                    Arch config: devcontainer.json + Dockerfile
    fedora/                  Fedora config: devcontainer.json + Dockerfile
    debian/                  Debian config: devcontainer.json + Dockerfile
    start-vnc.sh             Starts the VNC server and the noVNC bridge
    xstartup                 Plasma session startup script
scripts/
    install-desktop.sh       Installs the desktop on a live Codespace (no rebuild)
    launch-distro.sh         Boots and manages Plasma sidecar containers
    tune-kde.sh              Applies the tuned Plasma profile
    status.sh                Health check; prints every desktop URL
docker-compose.yml           Boots multiple sidecars at once (Ubuntu config)
Makefile                     Shortcuts for common tasks
```

## Common tasks

```bash
bash .devcontainer/start-vnc.sh   # restart the main desktop
./scripts/status.sh               # show status and URLs
tail -n 50 /tmp/vncserver.log     # VNC server log
tail -n 50 /tmp/novnc.log         # noVNC bridge log
```

Minimal CLI-only containers without a desktop (Ubuntu configuration):

```bash
docker run -it --rm ubuntu:24.04 bash
docker run -it --rm archlinux:latest bash
docker run -it --rm fedora:latest bash
docker run -it --rm kalilinux/kali-rolling bash
```

Kali with a desktop (large download):

```bash
docker run -d --name vm-kali -p 3006:6080 dorowu/kali-linux-vnc:latest
# then open port 3006
```

Copy files between the Codespace and a sidecar:

```bash
docker cp ./file.txt vm-ubuntu:/config/
docker cp vm-ubuntu:/config/output.txt ./
```

## Troubleshooting

| Symptom | Solution |
| --- | --- |
| No configuration choice shown | Create the Codespace via Code, then Codespaces, then ... then "New with options". The dropdown lists every configuration in `.devcontainer/`. |
| Port 6080 refuses connections | The desktop is still starting, or it stopped. Run `bash .devcontainer/start-vnc.sh` and check `/tmp/vncserver.log` and `/tmp/novnc.log`. Plasma takes longer than light desktops on first start. |
| Grey or black screen in the browser | The session script failed. Inspect `~/.vnc/*.log`, then run `vncserver -kill :1` and restart. |
| Authentication failed | The default password is `vscode`. Reset it with `VNC_PASSWORD=vscode bash .devcontainer/start-vnc.sh`. |
| `docker: permission denied` | Sidecars need the Ubuntu configuration. There, run `newgrp docker`, or rebuild so the docker-in-docker feature applies. |
| Sidecar exits immediately | Usually out of memory. Stop other containers or use a larger machine, then check `docker logs <name>`. |
| Sluggish desktop | Lower the resolution, close tabs inside the desktop browser, stop unused sidecars, or move to a larger machine. |

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
