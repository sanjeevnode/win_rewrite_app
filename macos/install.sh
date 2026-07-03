#!/usr/bin/env bash
# Gemini Rewrite — macOS installer (Hammerspoon)
# Works standalone via:
#   curl -fsSL https://raw.githubusercontent.com/sanjeevnode/win_rewrite_app/master/macos/install.sh | bash
set -euo pipefail

HS_DIR="$HOME/.hammerspoon"
CONFIG="$HS_DIR/gemini-rewrite-config.json"
RAW_BASE="https://raw.githubusercontent.com/sanjeevnode/win_rewrite_app/master/macos"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" 2>/dev/null && pwd || echo "")"

# --- Hammerspoon: install automatically if missing ---
if [ ! -d "/Applications/Hammerspoon.app" ] && [ ! -d "$HOME/Applications/Hammerspoon.app" ]; then
  echo "Hammerspoon not found — downloading the latest release..."
  URL="$(curl -fsSL https://api.github.com/repos/Hammerspoon/hammerspoon/releases/latest \
    | grep -o 'https://[^"]*Hammerspoon-[^"]*\.zip' | head -1)"
  if [ -z "$URL" ]; then
    echo "Could not resolve the Hammerspoon download URL."
    echo "Install it manually: brew install --cask hammerspoon"
    exit 1
  fi
  TMP="$(mktemp -d)"
  curl -fsSL -o "$TMP/hs.zip" "$URL"
  mkdir -p "$HOME/Applications"
  ditto -xk "$TMP/hs.zip" "$HOME/Applications/"
  rm -rf "$TMP"
  echo "Hammerspoon installed to ~/Applications."
fi

# --- Gemini Rewrite module: use local copy or fetch from the repo ---
mkdir -p "$HS_DIR"
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/gemini-rewrite.lua" ]; then
  cp "$SCRIPT_DIR/gemini-rewrite.lua" "$HS_DIR/gemini-rewrite.lua"
else
  curl -fsSL -o "$HS_DIR/gemini-rewrite.lua" "$RAW_BASE/gemini-rewrite.lua"
fi

# --- Config ---
if [ ! -f "$CONFIG" ]; then
  KEY=""
  if [ -t 0 ]; then
    read -r -p "Enter your Gemini API key (free at https://aistudio.google.com/apikey): " KEY
  elif [ -e /dev/tty ]; then
    # piped install (curl | bash): read from the terminal directly
    printf "Enter your Gemini API key (free at https://aistudio.google.com/apikey): " > /dev/tty
    read -r KEY < /dev/tty
  fi
  cat > "$CONFIG" <<EOF
{
  "apiKey": "${KEY:-YOUR_API_KEY_HERE}",
  "model": "gemini-3.1-flash-lite",
  "hotkeyMods": ["ctrl", "alt", "cmd"],
  "hotkeyKey": "c"
}
EOF
  chmod 600 "$CONFIG"
  echo "Config written to $CONFIG"
  [ -z "$KEY" ] && echo "NOTE: no key entered — edit $CONFIG and set apiKey."
else
  echo "Keeping existing config at $CONFIG"
fi

# --- Wire into init.lua ---
INIT="$HS_DIR/init.lua"
REQUIRE_LINE='require("gemini-rewrite").start()'
touch "$INIT"
if ! grep -qF "$REQUIRE_LINE" "$INIT"; then
  printf '\n%s\n' "$REQUIRE_LINE" >> "$INIT"
  echo "Added Gemini Rewrite to $INIT"
fi

open -a Hammerspoon || true

echo
echo "Done! Final steps:"
echo "  1. Grant Hammerspoon Accessibility permission if asked"
echo "     (System Settings -> Privacy & Security -> Accessibility)."
echo "  2. Click the Hammerspoon menu-bar icon -> Reload Config."
echo "  3. Select text anywhere and press Ctrl+Alt+Cmd+C."
echo
echo "Edit $CONFIG to change the key, model, or hotkey (then Reload Config)."
