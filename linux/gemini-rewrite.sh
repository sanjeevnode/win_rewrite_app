#!/usr/bin/env bash
# Gemini Rewrite for Linux (X11)
# Bind this script to a hotkey (e.g. Ctrl+Alt+C) in your desktop
# environment's keyboard settings. When triggered, it copies the current
# selection, rewrites it via the Gemini API, and pastes it back in place.
#
# Requires: xdotool, xclip, curl, jq, libnotify (notify-send)
# Config:   ~/.config/gemini-rewrite/config
set -uo pipefail

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/gemini-rewrite/config"
DEFAULT_MODEL="gemini-3.1-flash-lite"

note() { command -v notify-send >/dev/null && notify-send "Gemini Rewrite" "$1" || echo "Gemini Rewrite: $1" >&2; }

for dep in xdotool xclip curl jq; do
  command -v "$dep" >/dev/null || { note "Missing dependency: $dep"; exit 1; }
done

[ -f "$CONFIG" ] || { note "Missing config. Run install.sh or create $CONFIG"; exit 1; }
# shellcheck disable=SC1090
source "$CONFIG"
API_KEY="${API_KEY:-}"
MODEL="${MODEL:-$DEFAULT_MODEL}"
[ -n "$API_KEY" ] && [ "$API_KEY" != "YOUR_API_KEY_HERE" ] || { note "Set API_KEY in $CONFIG"; exit 1; }

# Save current clipboard (may be empty)
SAVED="$(xclip -selection clipboard -o 2>/dev/null || true)"

# Copy the current selection
xclip -selection clipboard -i < /dev/null   # clear so we can detect the copy
xdotool key --clearmodifiers ctrl+c
sleep 0.25
TEXT="$(xclip -selection clipboard -o 2>/dev/null || true)"

if [ -z "${TEXT//[[:space:]]/}" ]; then
  printf '%s' "$SAVED" | xclip -selection clipboard -i
  note "No text selected."
  exit 0
fi

PROMPT="Rewrite/paraphrase the following text. Preserve the original meaning, tone, and approximate length. Return ONLY the rewritten text with no extra commentary, no quotation marks wrapping it, and no markdown formatting:

$TEXT"

BODY="$(jq -n --arg t "$PROMPT" \
  '{contents:[{parts:[{text:$t}]}],generationConfig:{thinkingConfig:{thinkingBudget:0}}}')"

RESP="$(curl -sS --max-time 15 -w '\n%{http_code}' \
  -H "Content-Type: application/json" -H "x-goog-api-key: $API_KEY" \
  -d "$BODY" \
  "https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent" 2>/dev/null)"
STATUS="${RESP##*$'\n'}"
JSON="${RESP%$'\n'*}"

restore() { printf '%s' "$SAVED" | xclip -selection clipboard -i; }

case "$STATUS" in
  200) ;;
  401|403) restore; note "Invalid API key (HTTP $STATUS)."; exit 1 ;;
  429)     restore; note "Rate limit hit (HTTP 429). Try again in a moment."; exit 1 ;;
  000|"")  restore; note "Network error — check your internet connection."; exit 1 ;;
  *)       restore; note "Gemini API error (HTTP $STATUS)."; exit 1 ;;
esac

OUT="$(printf '%s' "$JSON" | jq -r '.candidates[0].content.parts[0].text // empty')"
[ -n "$OUT" ] || { restore; note "Couldn't parse Gemini response."; exit 1; }

# Sanitize: strip markdown fences and one pair of wrapping quotes
OUT="$(printf '%s' "$OUT" | sed -e '1s/^```[a-zA-Z]*$//' -e '$s/^```$//' | sed -e '/./,$!d')"
OUT="$(printf '%s' "$OUT" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
case "$OUT" in
  \"*\") OUT="${OUT#\"}"; OUT="${OUT%\"}" ;;
  \'*\') OUT="${OUT#\'}"; OUT="${OUT%\'}" ;;
esac

# Paste the rewritten text over the selection, then restore the clipboard
printf '%s' "$OUT" | xclip -selection clipboard -i
xdotool key --clearmodifiers ctrl+v
sleep 0.5
restore
note "Rewritten ✓"
