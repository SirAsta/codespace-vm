# Fedora Codespace image.
#
# Latest Fedora with KDE Plasma, TigerVNC serving the desktop session,
# and a noVNC/websockify bridge so the desktop opens in any modern
# browser. Selected through .devcontainer/fedora/devcontainer.json.
#
# Fedora ships Plasma Wayland-first, so the X11 session package
# (plasma-workspace-x11, providing startplasma-x11) is installed
# explicitly. KWin's X11 components arrive as its dependencies.
FROM fedora:latest

ENV LANG=C.UTF-8 \
    TZ=Etc/UTC \
    VNC_PASSWORD=vscode \
    RESOLUTION=1600x900 \
    NOVNC_PATH=/opt/novnc

# Plasma, the VNC server, a browser, fonts and general utilities.
RUN dnf install -y \
      plasma-desktop plasma-workspace plasma-workspace-x11 \
      konsole dolphin kate ark gwenview \
      tigervnc-server \
      firefox \
      xrdb xset xsetroot \
      dbus-x11 \
      dejavu-sans-fonts dejavu-sans-mono-fonts \
      liberation-sans-fonts liberation-mono-fonts \
      google-noto-sans-fonts google-noto-sans-mono-fonts \
      xorg-x11-fonts-misc \
      git sudo shadow-utils bash \
      python3 python3-pip procps-ng \
      curl wget nano htop tar gzip \
    && dnf clean all \
    && rm -rf /var/cache/dnf

# Best-effort extras: the Breeze icon theme and full vim.
# The desktop works without them, so this step never fails the build.
RUN dnf install -y breeze-icon-theme vim-enhanced || true

# Pinned noVNC web client plus the websockify bridge, then verify the
# whole remote-desktop toolchain is present so failures surface at build.
RUN curl -fsSL https://github.com/novnc/noVNC/archive/refs/tags/v1.5.0.tar.gz \
      | tar xzf - -C /opt \
    && mv /opt/noVNC-1.5.0 /opt/novnc \
    && ls /opt/novnc/vnc.html \
    && PIP_BREAK_SYSTEM_PACKAGES=1 pip install --no-cache-dir websockify \
    && command -v websockify \
    && command -v vncserver \
    && ls /usr/bin/startplasma-x11

# Non-root desktop user with passwordless sudo (dev container standard).
RUN useradd -m -s /bin/bash -u 1000 vscode \
    && echo "vscode ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/vscode \
    && chmod 440 /etc/sudoers.d/vscode

# VNC startup script and the Plasma session configuration.
# The build context is .devcontainer/, so these paths are local to it.
COPY start-vnc.sh /usr/local/bin/start-vnc.sh
COPY xstartup /etc/codespace-vm/xstartup
RUN chmod +x /usr/local/bin/start-vnc.sh /etc/codespace-vm/xstartup \
    && chown -R vscode:vscode /etc/codespace-vm

EXPOSE 6080 5901

USER vscode
WORKDIR /workspaces
