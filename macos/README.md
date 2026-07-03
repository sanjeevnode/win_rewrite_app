# Gemini Rewrite — macOS

Select text in any app, press **Ctrl + Alt + Cmd + C**, and the selection is
rewritten by the Gemini API and pasted back in place. Built on
[Hammerspoon](https://www.hammerspoon.org/).

## Install (DMG — easiest)

1. Download **gemini-rewrite-macos.dmg** from the
   [latest release](https://github.com/sanjeevnode/win_rewrite_app/releases/latest),
   open it, and double-click **Gemini Rewrite Installer**.
2. If [Hammerspoon](https://www.hammerspoon.org/) (the engine this tool
   runs on) isn't installed, the installer offers to download and install
   it for you automatically.
3. Enter your API key when prompted — the installer does the rest and
   launches Hammerspoon.

Note: the installer app is unsigned, so on first open macOS may block it —
right-click → Open (or allow it under System Settings → Privacy & Security).

## Install (script)

```sh
brew install --cask hammerspoon   # if you don't have it
./install.sh
```

The installer prompts for your Gemini API key (free at
https://aistudio.google.com/apikey), copies the script into
`~/.hammerspoon/`, and wires it into your Hammerspoon `init.lua`.

Then open Hammerspoon, grant it **Accessibility** permission
(System Settings → Privacy & Security → Accessibility — required to send
Cmd+C/Cmd+V), and choose **Reload Config** from its menu-bar icon.

## Configure

Edit `~/.hammerspoon/gemini-rewrite-config.json`:

```json
{
  "apiKey": "YOUR_API_KEY_HERE",
  "model": "gemini-3.1-flash-lite",
  "hotkeyMods": ["ctrl", "alt", "cmd"],
  "hotkeyKey": "c"
}
```

After editing, reload the Hammerspoon config. Valid modifier names:
`cmd`, `ctrl`, `alt`, `shift`.

## Uninstall

Remove the `require("gemini-rewrite").start()` line from
`~/.hammerspoon/init.lua` and delete `~/.hammerspoon/gemini-rewrite.lua`
and the config file, then reload Hammerspoon.
