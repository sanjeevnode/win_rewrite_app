# Gemini Rewrite — macOS

Select text in any app, press **Ctrl + Alt + Cmd + C**, and the selection is
rewritten by the Gemini API and pasted back in place. Built on
[Hammerspoon](https://www.hammerspoon.org/).

## Install (one command — recommended)

Paste this in Terminal:

```sh
curl -fsSL https://raw.githubusercontent.com/sanjeevnode/win_rewrite_app/master/macos/install.sh | bash
```

It installs Hammerspoon automatically if missing, prompts for your Gemini
API key (free at https://aistudio.google.com/apikey), and wires everything
up. Then grant Hammerspoon **Accessibility** permission when asked
(System Settings → Privacy & Security → Accessibility — required to send
Cmd+C/Cmd+V) and choose **Reload Config** from its menu-bar icon.

## Install (DMG)

A `gemini-rewrite-macos.dmg` with a double-click installer app ships with
each [release](https://github.com/sanjeevnode/win_rewrite_app/releases/latest),
but because it is not notarized with Apple, modern macOS (Sequoia and
later) refuses to open it, claiming the app is "damaged". To use it anyway,
clear the download quarantine flag first:

```sh
xattr -d com.apple.quarantine ~/Downloads/gemini-rewrite-macos.dmg
```

then open the DMG and double-click **Gemini Rewrite Installer**. If you'd
rather not touch Terminal at all there is no way around notarization —
use the one-command install above instead (it's also Terminal, but one
line).

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
