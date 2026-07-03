#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; ---------------------------------------------------------------
; Global Text Rewrite/Paraphrase Tool
; Hotkey: Ctrl+Win+Alt+C  — rewrites the selected text via Gemini
; ---------------------------------------------------------------

A_IconTip := "Gemini Rewrite (Ctrl+Win+Alt+C)"
TraySetIcon("shell32.dll", 172)  ; pencil-ish icon

CONFIG_FILE := A_ScriptDir "\config.ini"
DEFAULT_MODEL := "gemini-3.1-flash-lite"
HTTP_TIMEOUT_S := 15

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

^#!c:: RewriteSelection()

RewriteSelection() {
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
