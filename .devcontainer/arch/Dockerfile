# Arch Linux Codespace image.
#
# Rolling-release Arch with KDE Plasma, TigerVNC serving the desktop
# session, and a noVNC/websockify bridge so the desktop opens in any
# modern browser. Selected through .devcontainer/arch/devcontainer.json.
FROM archlinux:latest

ENV LANG=C.UTF-8 \
    TZ=Etc/UTC \
    VNC_PASSWORD=vscode \
    RESOLUTION=1600x900 \
    NOVNC_PATH=/opt/novnc

# Full system upgrade plus Plasma, the VNC server, a browser, fonts
# and general utilities.
RUN pacman -Syu --noconfirm \
      plasma-desktop \
      kwin \
      konsole dolphin kate ark gwenview \
      breeze breeze-icons \
      tigervnc \
      firefox \
      xorg-xsetroot xorg-xrdb xorg-xset \
      dbus \
      ttf-dejavu ttf-liberation noto-fonts ttf-hack \
      git sudo shadow bash \
      python python-pip procps-ng \
      curl wget vim nano htop tar gzip \
    && pacman -Scc --noconfirm \
    && rm -rf /var/cache/pacman/pkg/*

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
