#!/usr/bin/env bash
#
# tune-kde.sh
#
# Applies a tuned KDE Plasma profile optimized for VNC and browser use:
# the Breeze Dark theme, KWin compositing and desktop effects disabled
# for responsiveness, Baloo file indexing disabled, automatic suspend
# disabled, and a set of sensible workspace defaults.
#
# Existing settings are preserved wherever the profile does not override
# them. Restart the desktop (or log out and back in) to apply everything.
#
# Usage:
#   bash scripts/tune-kde.sh                            # tune this machine
#   bash scripts/tune-kde.sh --container vm-ubuntu  # tune a running sidecar
set -euo pipefail

# Tune a running sidecar by copying this script into it and executing it
# there as the desktop user.
if [ "${1:-}" = "--container" ]; then
  NAME="${2:?usage: $0 --container <container-name>}"
  if ! docker ps --format '{{.Names}}' | grep -qx "$NAME"; then
    echo "Container '$NAME' is not running. See: ./scripts/launch-distro.sh ps"
    exit 1
  fi
  echo "[tune-kde] Tuning $NAME ..."
  docker cp "$0" "$NAME:/tmp/tune-kde.sh"
  docker exec -u abc -e HOME=/config "$NAME" bash /tmp/tune-kde.sh
  echo ""
  echo "✅ $NAME tuned — refresh the browser tab to see Breeze Dark + snappier windows."
  exit 0
fi

# Python merges the profile into the existing config files without
# discarding unrelated settings. Install it if the system lacks it.
if ! command -v python3 >/dev/null 2>&1; then
  echo "[tune-kde] python3 missing, attempting install..."
  if [ -f /etc/os-release ]; then # shellcheck disable=SC1091
    . /etc/os-release
  fi
  case "${ID:-unknown}" in
    ubuntu|debian) sudo -n apt-get update -qq && sudo -n apt-get install -y -qq python3 || true ;;
    arch)          sudo -n pacman -Sy --noconfirm python || true ;;
    fedora)        sudo -n dnf install -y -q python3 || true ;;
    alpine)        sudo -n apk add --no-cache python3 || true ;;
  esac
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is required but could not be installed. Install it and re-run."
  exit 1
fi

echo "[tune-kde] Writing tuned profile to $HOME/.config ..."

python3 - <<'PYEOF'
import configparser, os

CONF = os.path.join(os.path.expanduser("~"), ".config")
os.makedirs(CONF, exist_ok=True)

def merge(fname, data):
    """Merge key/value pairs into a KDE config file, preserving other keys."""
    path = os.path.join(CONF, fname)
    cfg = configparser.ConfigParser()
    cfg.optionxform = str  # KDE keys are case-sensitive
    if os.path.exists(path):
        try:
            cfg.read(path)
        except Exception:
            pass
    for section, keys in data.items():
        if not cfg.has_section(section):
            cfg.add_section(section)
        for k, v in keys.items():
            cfg.set(section, k, v)
    with open(path, "w") as f:
        cfg.write(f)
    print(f"  + {fname}")

FX = ["blur", "contrast", "coverswitch", "cube", "desktopgrid", "fallapart",
      "flipswitch", "glide", "highlightwindow", "invert", "lookingglass",
      "magiclamp", "magnifier", "maximize", "minimizeanimation", "mouseclick",
      "mousemark", "outlinedwindow", "presentwindows", "resize", "screenshot",
      "sessionquit", "shake", "sheet", "showfps", "showpaint", "slide",
      "slideback", "slidingpopups", "snaphelper", "startupfeedback",
      "thumbnailaside", "trackmouse", "wobblywindows", "zoom"]

# KWin: compositing and effects off, instant animations. Remote protocols
# cannot sustain composited rendering, so this is the main VNC speedup.
kwin = {
    "Compositing": {
        "Enabled": "false",
        "GLCore": "false",
        "OpenGLIsUnsafe": "true",
        "AnimationSpeed": "3",
    },
    "Desktops": {"Number": "2", "Rows": "1"},
    "Plugins": {"kwin4_effect_fadeEnabled": "false",
                **{f"{fx}Enabled": "false" for fx in FX}},
}
for fx in FX:
    kwin[f"Effect-{fx}"] = {"Enabled": "false"}
merge("kwinrc", kwin)

# Appearance: Breeze Dark theme, icons and default applications.
merge("kdeglobals", {
    "KDE": {"LookAndFeelPackage": "org.kde.breezedark.desktop",
            "SingleClick": "false"},
    "General": {
        "ColorScheme": "BreezeDark",
        "Name": "BreezeDark",
        "widgetStyle": "Breeze",
        "font": "Noto Sans,10,-1,0,50,0,0,0,0,0",
        "fixed": "Hack,10,-1,5,50,0,0,0,0,0",
        "TerminalApplication": "konsole",
        "BrowserApplication": "firefox",
    },
    "Icons": {"Theme": "breeze-dark"},
})

# Resource savers: no file indexing, no suspend, quieter notifications.
merge("baloofilerc", {"Basic Settings": {"Indexing-Enabled": "false"}})
merge("powerdevilrc", {
    "AC": {"SuspendSession": "false"},
    "Battery": {"SuspendSession": "false"},
    "LowBattery": {"SuspendSession": "false"},
})
merge("plasmanotifyrc", {"Notifications": {"LowPriorityHistoryLimit": "5"}})
merge("krunnerrc", {"Plugins": {"baloosearchEnabled": "false"}})
PYEOF

# Stop the Baloo indexer if it is already running. Best effort: outside a
# live Plasma session there is no daemon to stop, and the config above
# still applies on next login.
if command -v balooctl >/dev/null 2>&1; then
  balooctl disable 2>/dev/null || balooctl suspend 2>/dev/null || true
fi

echo ""
echo "✅ Tuned KDE profile applied."
echo "   Restart the desktop to apply everything:  DESKTOP=kde bash .devcontainer/start-vnc.sh"
echo "   (…or Plasma menu → Leave → Log Out, then reconnect.)"
