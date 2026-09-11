# Main Codespace image.
#
# Ubuntu with KDE Plasma, TigerVNC serving the desktop session, and a
# noVNC/websockify bridge so the desktop opens in any modern browser.
# Compositing is disabled at runtime so Plasma stays responsive over VNC.
FROM mcr.microsoft.com/devcontainers/base:ubuntu

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC \
    VNC_PASSWORD=vscode \
    RESOLUTION=1600x900 \
    NOVNC_PATH=/usr/share/novnc

# Minimal KDE Plasma install, a small tuned application set, the VNC stack,
# a browser, fonts and general utilities.
RUN apt-get update && apt-get install -y --no-install-recommends \
      kde-plasma-desktop \
      plasma-workspace \
      kwin-x11 \
      konsole \
      dolphin \
      kate \
      ark \
      gwenview \
      breeze \
      breeze-icon-theme \
      dbus-x11 \
      x11-utils \
      x11-xserver-utils \
      xfonts-base \
      fonts-dejavu \
      fonts-liberation \
      fonts-noto \
      fonts-hack \
      tigervnc-standalone-server \
      tigervnc-common \
      novnc \
      websockify \
      supervisor \
      firefox \
      python3 \
      curl \
      wget \
      git \
      vim \
      nano \
      htop \
      net-tools \
      iputils-ping \
      ca-certificates \
      tzdata \
      locales \
      sudo \
      unzip \
      zip \
    && locale-gen en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Fail the build early if noVNC or the Plasma X11 session is missing.
RUN ls /usr/share/novnc/vnc.html && ls /usr/bin/startplasma-x11

# VNC startup script and the Plasma session configuration.
# The build context is .devcontainer/, so these paths are local to it.
COPY start-vnc.sh /usr/local/bin/start-vnc.sh
COPY xstartup /etc/codespace-vm/xstartup
RUN chmod +x /usr/local/bin/start-vnc.sh \
    && chmod +x /etc/codespace-vm/xstartup \
    && mkdir -p /tmp /var/log/supervisor \
    && chown -R vscode:vscode /etc/codespace-vm 2>/dev/null || true

# Port forwarding is declared in devcontainer.json; EXPOSE documents intent.
EXPOSE 6080 5901

USER vscode
WORKDIR /workspaces
