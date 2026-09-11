# Main Codespace image.
#
# Ubuntu with a lightweight XFCE desktop, TigerVNC serving the desktop
# session, and a noVNC/websockify bridge so the desktop opens in any
# modern browser.
FROM mcr.microsoft.com/devcontainers/base:ubuntu

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC \
    VNC_PASSWORD=vscode \
    RESOLUTION=1280x800 \
    NOVNC_PATH=/usr/share/novnc

# Desktop environment, VNC stack, browser, fonts and general utilities.
RUN apt-get update && apt-get install -y --no-install-recommends \
      xfce4 \
      xfce4-goodies \
      xfce4-terminal \
      thunar-archive-plugin \
      dbus-x11 \
      x11-utils \
      x11-xserver-utils \
      xfonts-base \
      xfonts-75dpi \
      xfonts-100dpi \
      fonts-dejavu \
      fonts-liberation \
      fonts-noto \
      tigervnc-standalone-server \
      tigervnc-common \
      novnc \
      websockify \
      supervisor \
      firefox \
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

# Fail the build early if the noVNC web client is missing.
RUN ls -la /usr/share/novnc/vnc.html || (echo "ERROR: novnc not found at /usr/share/novnc" && exit 1)

# VNC startup script and session configuration.
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
