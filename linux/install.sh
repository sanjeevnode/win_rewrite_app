#!/usr/bin/env bash
# Gemini Rewrite — Linux (X11) installer
set -euo pipefail

BIN_DIR="$HOME/.local/bin"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/gemini-rewrite"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MISSING=()
for dep in xdotool xclip curl jq; do
  command -v "$dep" >/dev/null || MISSING+=("$dep")
done
if [ "${#MISSING[@]}" -gt 0 ]; then
  echo "Missing dependencies: ${MISSING[*]}"
  echo "Install them first, e.g.:"
  echo "  Debian/Ubuntu: sudo apt install ${MISSING[*]}"
  echo "  Fedora:        sudo dnf install ${MISSING[*]}"
  echo "  Arch:          sudo pacman -S ${MISSING[*]}"
  exit 1
fi

if [ -z "${DISPLAY:-}" ] || [ "${XDG_SESSION_TYPE:-}" = "wayland" ]; then
  echo "Warning: this tool targets X11. On Wayland, global key injection"
  echo "(xdotool) generally will not work in native Wayland apps."
fi

mkdir -p "$BIN_DIR" "$CONFIG_DIR"
install -m 755 "$SCRIPT_DIR/gemini-rewrite.sh" "$BIN_DIR/gemini-rewrite"

if [ ! -f "$CONFIG_DIR/config" ]; then
  read -r -p "Enter your Gemini API key (free at https://aistudio.google.com/apikey): " KEY
  cat > "$CONFIG_DIR/config" <<EOF
API_KEY=$KEY
MODEL=gemini-3.1-flash-lite
EOF
  chmod 600 "$CONFIG_DIR/config"
  echo "Config written to $CONFIG_DIR/config"
else
  echo "Keeping existing config at $CONFIG_DIR/config"
fi

echo
echo "Installed to $BIN_DIR/gemini-rewrite"
echo
echo "Last step — bind it to a hotkey in your desktop environment:"
echo "  GNOME: Settings -> Keyboard -> Custom Shortcuts -> add"
echo "         command '$BIN_DIR/gemini-rewrite', e.g. Ctrl+Alt+C"
echo "  KDE:   System Settings -> Shortcuts -> Custom Shortcuts"
echo "  i3/sxhkd: bindsym \$mod+ctrl+c exec $BIN_DIR/gemini-rewrite"
echo
echo "Then select text anywhere and press your hotkey."
