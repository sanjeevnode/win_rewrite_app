#!/usr/bin/env bash
# Gemini Rewrite — macOS installer (Hammerspoon)
set -euo pipefail

HS_DIR="$HOME/.hammerspoon"
CONFIG="$HS_DIR/gemini-rewrite-config.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! [ -d "/Applications/Hammerspoon.app" ] && ! command -v hs >/dev/null 2>&1; then
  echo "Hammerspoon is required. Install it first:"
  echo "  brew install --cask hammerspoon"
  echo "or download from https://www.hammerspoon.org/"
  exit 1
fi

mkdir -p "$HS_DIR"
cp "$SCRIPT_DIR/gemini-rewrite.lua" "$HS_DIR/gemini-rewrite.lua"

if [ ! -f "$CONFIG" ]; then
  read -r -p "Enter your Gemini API key (free at https://aistudio.google.com/apikey): " KEY
  cat > "$CONFIG" <<EOF
{
  "apiKey": "$KEY",
  "model": "gemini-3.1-flash-lite",
  "hotkeyMods": ["ctrl", "alt", "cmd"],
  "hotkeyKey": "c"
}
EOF
  echo "Config written to $CONFIG"
else
  echo "Keeping existing config at $CONFIG"
fi

INIT="$HS_DIR/init.lua"
REQUIRE_LINE='require("gemini-rewrite").start()'
touch "$INIT"
if ! grep -qF "$REQUIRE_LINE" "$INIT"; then
  printf '\n%s\n' "$REQUIRE_LINE" >> "$INIT"
  echo "Added Gemini Rewrite to $INIT"
fi

echo
echo "Done! Now:"
echo "  1. Open Hammerspoon (grant Accessibility permission when asked)."
echo "  2. Click the Hammerspoon menu-bar icon -> Reload Config."
echo "  3. Select text anywhere and press Ctrl+Alt+Cmd+C."
echo
echo "Edit $CONFIG to change the key, model, or hotkey (then Reload Config)."
