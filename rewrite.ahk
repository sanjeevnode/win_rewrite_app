#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; ---------------------------------------------------------------
; Global Text Rewrite/Paraphrase Tool
; Hotkey: Ctrl+Win+Alt+C  — rewrites the selected text via Gemini
; ---------------------------------------------------------------

CONFIG_FILE := A_ScriptDir "\config.ini"
DEFAULT_MODEL := "gemini-3.1-flash-lite"
DEFAULT_HOTKEY := "^#!c"  ; Ctrl+Win+Alt+C
HTTP_TIMEOUT_S := 15
UNINST_REG := "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\GeminiRewrite"
MODELS := ["gemini-3.1-flash-lite", "gemini-3.5-flash", "gemini-2.5-flash", "gemini-2.5-flash-lite", "gemini-3-flash"]
HOTKEYS := Map(
    "Ctrl + Win + Alt + C", "^#!c",
    "Ctrl + Alt + R",       "^!r",
    "Ctrl + Shift + Q",     "^+q",
    "Win + Shift + Z",      "#+z",
    "Ctrl + Alt + Space",   "^!Space")
HOTKEY_LABELS := ["Ctrl + Win + Alt + C", "Ctrl + Alt + R", "Ctrl + Shift + Q", "Win + Shift + Z", "Ctrl + Alt + Space"]
CURRENT_HOTKEY := ""

if (A_Args.Length && A_Args[1] = "/uninstall") {
    DoUninstall()
    ExitApp
}

TraySetIcon("shell32.dll", 172)  ; pencil-ish icon

; --- Tray menu: Settings / Restart / Uninstall / Exit ---
A_TrayMenu.Delete()
A_TrayMenu.Add("Settings…", ShowSettings)
A_TrayMenu.Add("Restart", (*) => Reload())
A_TrayMenu.Add()
A_TrayMenu.Add("Uninstall", TrayUninstall)
A_TrayMenu.Add("Exit", (*) => ExitApp())
A_TrayMenu.Default := "Settings…"
OnMessage(0x404, TrayClick)  ; single left-click on tray icon opens Settings

TrayClick(wParam, lParam, *) {
    if (lParam = 0x202)  ; WM_LBUTTONUP
        SetTimer(() => ShowSettings(), -50)
}

RegisterRewriteHotkey()

; --- Settings window ---
ShowSettings(*) {
    global
    static sg := ""
    if (sg is Gui) {
        sg.Show()
        return
    }
    sg := Gui("+AlwaysOnTop", "Gemini Rewrite — Settings")
    sg.SetFont("s10", "Segoe UI")
    sg.AddText(, "Gemini API key:")
    edKey := sg.AddEdit("xm w340", ReadApiKey())
    sg.AddText("xm y+10", "Model:")
    curModel := ReadModel()
    modelList := MODELS.Clone()
    idx := 0
    for i, m in modelList
        if (m = curModel)
            idx := i
    if !idx {
        modelList.Push(curModel), idx := modelList.Length
    }
    ddModel := sg.AddDropDownList("xm w340 Choose" idx, modelList)
    sg.AddText("xm y+10", "Hotkey:")
    hkList := HOTKEY_LABELS.Clone()
    idx := 0
    for i, lbl in hkList
        if (HOTKEYS[lbl] = CURRENT_HOTKEY)
            idx := i
    if !idx {
        hkList.Push(HotkeyToText(CURRENT_HOTKEY)), idx := hkList.Length
    }
    ddHotkey := sg.AddDropDownList("xm w340 Choose" idx, hkList)
    btnSave := sg.AddButton("xm y+16 w100 Default", "Save")
    btnCancel := sg.AddButton("x+10 w100", "Cancel")
    btnSave.OnEvent("Click", SaveSettings)
    btnCancel.OnEvent("Click", (*) => CloseSettings())
    sg.OnEvent("Close", (*) => CloseSettings())
    sg.Show()

    SaveSettings(*) {
        k := Trim(edKey.Value)
        if (k = "") {
            MsgBox("API key cannot be empty.", "Gemini Rewrite", "Iconx")
            return
        }
        IniWrite(k, CONFIG_FILE, "Gemini", "ApiKey")
        IniWrite(ddModel.Text, CONFIG_FILE, "Gemini", "Model")
        hk := HOTKEYS.Has(ddHotkey.Text) ? HOTKEYS[ddHotkey.Text] : CURRENT_HOTKEY
        IniWrite(hk, CONFIG_FILE, "Gemini", "Hotkey")
        RegisterRewriteHotkey()
        CloseSettings()
        Notify("Gemini Rewrite", "Settings saved ✓")
    }
    CloseSettings() {
        sg.Destroy()
        sg := ""
    }
}

TrayUninstall(*) {
    res := MsgBox("Uninstall Gemini Rewrite?`n`nThis removes the app, its settings, the startup shortcut, and the Control Panel entry.", "Gemini Rewrite", "YesNo Icon?")
    if (res = "Yes")
        DoUninstall()
}

DoUninstall() {
    global UNINST_REG
    ; Kill any other running instance of the app (not this process)
    myPid := DllCall("GetCurrentProcessId")
    try RunWait('taskkill /f /im rewrite.exe /fi "PID ne ' myPid '"', , "Hide")
    ; Remove startup shortcut and Control Panel entry
    lnk := A_Startup "\Gemini Rewrite.lnk"
    if FileExist(lnk)
        try FileDelete(lnk)
    try RegDeleteKey(UNINST_REG)
    ; Delete the install folder after this process exits (an exe can't
    ; delete itself while running)
    if A_IsCompiled
        Run(A_ComSpec ' /c timeout /t 2 /nobreak >nul & rd /s /q "' A_ScriptDir '"', , "Hide")
    ExitApp
}

ReadModel() {
    global CONFIG_FILE, DEFAULT_MODEL
    m := Trim(IniRead(CONFIG_FILE, "Gemini", "Model", DEFAULT_MODEL))
    return m = "" ? DEFAULT_MODEL : m
}

; Read API key at startup (re-read on each use too, so key swaps work live)
if (ReadApiKey() = "")
    Notify("Gemini Rewrite", "No API key found. Add it to config.ini under [Gemini] ApiKey=...", "warn")

ReadApiKey() {
    global CONFIG_FILE
    key := IniRead(CONFIG_FILE, "Gemini", "ApiKey", "")
    key := Trim(key)
    if (key = "" || key = "YOUR_API_KEY_HERE")
        return ""
    return key
}

Notify(title, msg, kind := "info") {
    opts := kind = "error" ? 3 : kind = "warn" ? 2 : 1
    TrayTip(msg, title, opts + 16)  ; +16 = don't play sound
}

RegisterRewriteHotkey() {
    global CONFIG_FILE, DEFAULT_HOTKEY, CURRENT_HOTKEY
    hk := Trim(IniRead(CONFIG_FILE, "Gemini", "Hotkey", DEFAULT_HOTKEY))
    if (hk = "")
        hk := DEFAULT_HOTKEY
    if (CURRENT_HOTKEY != "" && CURRENT_HOTKEY != hk)
        try Hotkey(CURRENT_HOTKEY, "Off")
    try {
        Hotkey(hk, (*) => RewriteSelection())
    } catch {
        Notify("Gemini Rewrite", "Invalid hotkey '" hk "' in config.ini — using default Ctrl+Win+Alt+C.", "warn")
        hk := DEFAULT_HOTKEY
        Hotkey(hk, (*) => RewriteSelection())
    }
    ; Conflict check: is this combo already registered system-wide by another app?
    if IsHotkeyTakenByOtherApp(hk)
        Notify("Gemini Rewrite", "Note: " HotkeyToText(hk) " is also registered by another application. Gemini Rewrite will intercept it while running.", "warn")
    CURRENT_HOTKEY := hk
    A_IconTip := "Gemini Rewrite (" HotkeyToText(hk) ")"
}

; Try to register the combo via the Win32 RegisterHotKey API — if that fails,
; some other application already owns it globally.
IsHotkeyTakenByOtherApp(hk) {
    mods := 0
    key := hk
    while InStr("^!+#", SubStr(key, 1, 1)) {
        c := SubStr(key, 1, 1)
        mods |= (c = "^") ? 0x2 : (c = "!") ? 0x1 : (c = "+") ? 0x4 : 0x8
        key := SubStr(key, 2)
    }
    vk := GetKeyVK(key)
    if (!vk || !mods)
        return false
    if DllCall("RegisterHotKey", "ptr", 0, "int", 0xB33F, "uint", mods, "uint", vk) {
        DllCall("UnregisterHotKey", "ptr", 0, "int", 0xB33F)
        return false
    }
    return true
}

HotkeyToText(hk) {
    out := ""
    key := hk
    while InStr("^!+#", SubStr(key, 1, 1)) {
        c := SubStr(key, 1, 1)
        out .= (c = "^") ? "Ctrl+" : (c = "!") ? "Alt+" : (c = "+") ? "Shift+" : "Win+"
        key := SubStr(key, 2)
    }
    return out StrUpper(key)
}

RewriteSelection(*) {
    apiKey := ReadApiKey()
    if (apiKey = "") {
        Notify("Gemini Rewrite", "Missing API key. Edit config.ini and add your Gemini API key.", "warn")
        return
    }

    ; 1. Save current clipboard (full, all formats)
    savedClip := ClipboardAll()

    ; 2. Copy the current selection
    A_Clipboard := ""
    Send("^c")
    if !ClipWait(1.5) {
        A_Clipboard := savedClip
        Notify("Gemini Rewrite", "No text selected.", "warn")
        return
    }

    text := A_Clipboard
    if (Trim(text) = "") {
        A_Clipboard := savedClip
        Notify("Gemini Rewrite", "Clipboard doesn't contain text.", "warn")
        return
    }

    Notify("Gemini Rewrite", "Rewriting…")

    try {
        rewritten := CallGemini(apiKey, text)
    } catch Error as e {
        A_Clipboard := savedClip
        Notify("Gemini Rewrite", e.Message, "error")
        return
    }

    rewritten := Sanitize(rewritten)
    if (rewritten = "") {
        A_Clipboard := savedClip
        Notify("Gemini Rewrite", "Empty response from Gemini.", "error")
        return
    }

    ; 3. Paste the rewritten text over the selection
    A_Clipboard := rewritten
    if !ClipWait(1.5) {
        A_Clipboard := savedClip
        Notify("Gemini Rewrite", "Failed to set clipboard.", "error")
        return
    }
    Send("^v")

    ; 4. Restore original clipboard after paste completes
    SetTimer(() => (A_Clipboard := savedClip), -600)
    Notify("Gemini Rewrite", "Rewritten ✓")
}

CallGemini(apiKey, text) {
    global HTTP_TIMEOUT_S
    url := "https://generativelanguage.googleapis.com/v1beta/models/" ReadModel() ":generateContent"

    prompt := "Rewrite/paraphrase the following text. Preserve the original meaning, tone, and approximate length. Return ONLY the rewritten text with no extra commentary, no quotation marks wrapping it, and no markdown formatting:`n`n" text
    body := '{"contents":[{"parts":[{"text":' JsonStr(prompt) '}]}],"generationConfig":{"thinkingConfig":{"thinkingBudget":0}}}'

    whr := ComObject("WinHttp.WinHttpRequest.5.1")
    t := HTTP_TIMEOUT_S * 1000
    whr.SetTimeouts(t, t, t, t)
    try {
        whr.Open("POST", url, false)
        whr.SetRequestHeader("Content-Type", "application/json")
        whr.SetRequestHeader("x-goog-api-key", apiKey)
        whr.Send(body)
    } catch Error as e {
        throw Error("Network error or timeout — check your internet connection. (" e.Message ")")
    }

    status := whr.Status
    resp := whr.ResponseText
    if (status = 401 || status = 403)
        throw Error("Invalid API key (HTTP " status "). Check config.ini.")
    if (status = 429)
        throw Error("Rate limit hit (HTTP 429). Try again in a moment.")
    if (status != 200)
        throw Error("Gemini API error (HTTP " status ").")

    ; Extract candidates[0].content.parts[0].text from the JSON response
    out := ExtractText(resp)
    if (out = "")
        throw Error("Couldn't parse Gemini response.")
    return out
}

; Minimal JSON string encoder
JsonStr(s) {
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, '"', '\"')
    s := StrReplace(s, "`r", "\r")
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`t", "\t")
    out := ""
    Loop Parse s {
        c := Ord(A_LoopField)
        out .= (c < 0x20) ? Format("\u{:04x}", c) : A_LoopField
    }
    return '"' out '"'
}

; Extract the first "text" field value from Gemini's JSON response,
; then JSON-unescape it.
ExtractText(json) {
    ; Find `"text":` then the string that follows
    pos := RegExMatch(json, 's)"text"\s*:\s*"((?:[^"\\]|\\.)*)"', &m)
    if !pos
        return ""
    s := m[1]
    out := ""
    i := 1
    len := StrLen(s)
    while (i <= len) {
        ch := SubStr(s, i, 1)
        if (ch = "\" && i < len) {
            nxt := SubStr(s, i + 1, 1)
            switch nxt {
                case "n": out .= "`n", i += 2
                case "r": out .= "`r", i += 2
                case "t": out .= "`t", i += 2
                case '"': out .= '"', i += 2
                case "\": out .= "\", i += 2
                case "/": out .= "/", i += 2
                case "b": out .= Chr(8), i += 2
                case "f": out .= Chr(12), i += 2
                case "u":
                    hex := SubStr(s, i + 2, 4)
                    out .= Chr("0x" hex), i += 6
                default: out .= nxt, i += 2
            }
        } else {
            out .= ch
            i += 1
        }
    }
    return out
}

; Defensive cleanup: strip markdown code fences and wrapping quotes
Sanitize(s) {
    s := Trim(s, " `t`r`n")
    ; strip ```lang ... ``` fences
    if RegExMatch(s, 's)^\x60{3}[a-zA-Z]*\R(.*?)\R?\x60{3}$', &m)
        s := Trim(m[1], " `t`r`n")
    ; strip one pair of wrapping quotes
    if (StrLen(s) >= 2) {
        first := SubStr(s, 1, 1), last := SubStr(s, -1)
        if ((first = '"' && last = '"') || (first = "'" && last = "'")
            || (first = Chr(0x201C) && last = Chr(0x201D)))
            s := Trim(SubStr(s, 2, StrLen(s) - 2), " `t`r`n")
    }
    return s
}
