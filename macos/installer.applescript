-- Gemini Rewrite — macOS GUI installer (compiled to an app by osacompile in CI)

on run
	set luaSource to POSIX path of (path to me) & "Contents/Resources/gemini-rewrite.lua"

	-- Hammerspoon is required
	set hsInstalled to false
	try
		do shell script "test -d /Applications/Hammerspoon.app -o -d $HOME/Applications/Hammerspoon.app"
		set hsInstalled to true
	end try
	if not hsInstalled then
		set choice to button returned of (display dialog "Gemini Rewrite runs on Hammerspoon (free, open source), which is not installed." & return & return & "Install it automatically now?" buttons {"Cancel", "Install Hammerspoon"} default button 2 with icon caution)
		if choice is not "Install Hammerspoon" then return
		try
			do shell script "url=$(curl -fsSL https://api.github.com/repos/Hammerspoon/hammerspoon/releases/latest | grep -o 'https://[^\"]*Hammerspoon-[^\"]*\\.zip' | head -1); test -n \"$url\"; tmp=$(mktemp -d); curl -fsSL -o \"$tmp/hs.zip\" \"$url\"; mkdir -p $HOME/Applications; ditto -xk \"$tmp/hs.zip\" $HOME/Applications/; rm -rf \"$tmp\"; test -d $HOME/Applications/Hammerspoon.app"
		on error
			display dialog "Automatic Hammerspoon install failed. Please install it manually from hammerspoon.org and run this installer again." buttons {"Open Website", "OK"} default button 1 with icon stop
			do shell script "open https://www.hammerspoon.org/"
			return
		end try
	end if

	-- Ask for the API key
	set dlg to display dialog "Enter your Gemini API key (free at aistudio.google.com/apikey):" default answer "" buttons {"Cancel", "Install"} default button 2 with icon note
	set apiKey to text returned of dlg
	if apiKey is "" then
		display dialog "No API key entered — installation cancelled." buttons {"OK"} default button 1 with icon stop
		return
	end if

	-- Install script + config + init.lua hook
	do shell script "mkdir -p $HOME/.hammerspoon && cp " & quoted form of luaSource & " $HOME/.hammerspoon/gemini-rewrite.lua"
	set cfg to "{\"apiKey\": \"" & apiKey & "\", \"model\": \"gemini-3.1-flash-lite\", \"hotkeyMods\": [\"ctrl\", \"alt\", \"cmd\"], \"hotkeyKey\": \"c\"}"
	do shell script "printf '%s' " & quoted form of cfg & " > $HOME/.hammerspoon/gemini-rewrite-config.json"
	do shell script "touch $HOME/.hammerspoon/init.lua; grep -qF 'require(\"gemini-rewrite\").start()' $HOME/.hammerspoon/init.lua || printf '\\nrequire(\"gemini-rewrite\").start()\\n' >> $HOME/.hammerspoon/init.lua"

	-- Launch/reload Hammerspoon
	do shell script "open -a Hammerspoon"

	display dialog "Installed!" & return & return & "1. If asked, grant Hammerspoon Accessibility permission (System Settings → Privacy & Security → Accessibility)." & return & "2. Click the Hammerspoon menu-bar icon → Reload Config." & return & return & "Then select text anywhere and press Ctrl+Alt+Cmd+C." buttons {"Done"} default button 1 with icon note
end run
