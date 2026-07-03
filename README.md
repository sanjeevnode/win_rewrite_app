# Gemini Rewrite Tool (AutoHotkey v2)

Select text in **any** Windows app, press **Ctrl + Win + Alt + C**, and the
selection is rewritten/paraphrased by the Gemini API and pasted back in place.
Runs silently in the system tray. Your original clipboard is restored after
each rewrite.

## Setup

1. Install [AutoHotkey v2](https://www.autohotkey.com/).
2. Copy `config.example.ini` to `config.ini` and set your Gemini API key:
   ```ini
   [Gemini]
   ApiKey=YOUR_API_KEY_HERE
   ```
   Get a free key at https://aistudio.google.com/apikey
3. Double-click `rewrite.ahk` to run it.

## Usage

1. Highlight text in any app (Notepad, browser, Word, Slack, VS Code…).
2. Press **Ctrl + Win + Alt + C**.
3. The selection is replaced with the rewritten text within a few seconds.
   A tray notification shows success ("Rewritten ✓") or the error reason.

The API key is re-read from `config.ini` on every hotkey press, so you can
swap keys without restarting the script.

## Start

- Double-click `rewrite.ahk` — it starts silently with only a tray icon
  (a pencil icon, possibly behind the `^` tray overflow arrow).
- Running it again while already active simply restarts it; duplicates are
  prevented (`#SingleInstance Force`).

## Stop

- Right-click the tray icon → **Exit**.
- To disable temporarily without exiting, use **Suspend Hotkeys** or
  **Pause Script** in the same tray menu.
- After editing the script, use **Reload Script** from the tray menu.

## Auto-start on login

By default the tool does **not** survive a reboot. To start it automatically
at every login:

1. Press `Win + R`, type `shell:startup`, press Enter.
2. Place a shortcut to `rewrite.ahk` in the folder that opens.

To undo auto-start, delete that shortcut.

## Known limitations

- Won't work in elevated/admin windows (AutoHotkey can't send keys to them
  unless the script itself runs as admin).
- Only works in apps that support standard Ctrl+C / Ctrl+V.
- If nothing is selected, you get a "No text selected" notification and
  nothing is changed.
