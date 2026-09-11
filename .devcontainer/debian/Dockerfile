# Debian Codespace image.
#
# Stable Debian with KDE Plasma, TigerVNC serving the desktop session,
# and a noVNC/websockify bridge so the desktop opens in any modern
# browser. Selected through .devcontainer/debian/devcontainer.json.
FROM debian:trixie

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    TZ=Etc/UTC \
    VNC_PASSWORD=vscode \
    RESOLUTION=1600x900 \
    NOVNC_PATH=/opt/novnc

# Plasma, the VNC server, a browser, fonts and general utilities.
RUN apt-get update && apt-get install -y --no-install-recommends \
      kde-plasma-desktop plasma-workspace kwin-x11 \
      konsole dolphin kate ark gwenview \
      breeze breeze-icon-theme \
      tigervnc-standalone-server tigervnc-common \
      firefox-esr \
      dbus-x11 x11-utils x11-xserver-utils \
      fonts-dejavu fonts-liberation fonts-noto fonts-hack \
      git sudo bash \
      python3 python3-pip procps \
      curl wget vim nano htop tar gzip ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

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
