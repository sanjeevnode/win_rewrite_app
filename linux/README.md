# Gemini Rewrite — Linux (X11)

Select text in any app, press your chosen hotkey, and the selection is
rewritten by the Gemini API and pasted back in place.

## Install

```sh
# dependencies (Debian/Ubuntu shown)
sudo apt install xdotool xclip curl jq libnotify-bin

./install.sh
```

The installer prompts for your Gemini API key (free at
https://aistudio.google.com/apikey), installs the script to
`~/.local/bin/gemini-rewrite`, and writes the config.

**Final step:** bind the command `~/.local/bin/gemini-rewrite` to a global
hotkey (e.g. Ctrl+Alt+C) in your desktop environment:

- **GNOME:** Settings → Keyboard → View and Customize Shortcuts → Custom Shortcuts
- **KDE:** System Settings → Shortcuts → Custom Shortcuts
- **i3:** `bindsym $mod+ctrl+c exec ~/.local/bin/gemini-rewrite`

## Configure

Edit `~/.config/gemini-rewrite/config`:

```sh
API_KEY=YOUR_API_KEY_HERE
MODEL=gemini-3.1-flash-lite
```

Changes apply on the next hotkey press. The hotkey itself is managed by
your desktop environment, so change it there.

## Wayland

Not supported by this script: Wayland blocks synthetic keystrokes into
other apps by design. Workarounds exist (`ydotool` with its daemon, or
running apps under XWayland) but are not wired up here.

## Uninstall

Delete `~/.local/bin/gemini-rewrite` and `~/.config/gemini-rewrite/`, and
remove the hotkey binding from your desktop settings.
