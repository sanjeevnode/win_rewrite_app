#Requires AutoHotkey v2.0
#SingleInstance Force

; ---------------------------------------------------------------
; Gemini Rewrite — Setup
; Compiled with Ahk2Exe; embeds rewrite.exe via FileInstall.
; Prompts for the Gemini API key + default model, installs to
; %LocalAppData%\GeminiRewrite, optional auto-start, launches app.
; ---------------------------------------------------------------

INSTALL_DIR := EnvGet("LOCALAPPDATA") "\GeminiRewrite"
MODELS := ["gemini-3.1-flash-lite", "gemini-3.5-flash", "gemini-2.5-flash", "gemini-2.5-flash-lite", "gemini-3-flash"]

g := Gui("+AlwaysOnTop", "Gemini Rewrite Setup")
g.SetFont("s10", "Segoe UI")
g.AddText(, "Rewrite selected text anywhere with Ctrl+Win+Alt+C.")
g.AddText("xm y+12", "Gemini API key (get one free at aistudio.google.com/apikey):")
edKey := g.AddEdit("xm w360 Password")
g.AddText("xm y+10", "Default model:")
ddModel := g.AddDropDownList("xm w360 Choose1", MODELS)
cbStart := g.AddCheckbox("xm y+12 Checked", "Start automatically when I log in")
btn := g.AddButton("xm y+16 w120 Default", "Install")
status := g.AddText("x+12 yp+4 w220", "")
btn.OnEvent("Click", DoInstall)
g.OnEvent("Close", (*) => ExitApp())
g.Show()

DoInstall(*) {
    global
    key := Trim(edKey.Value)
    if (key = "") {
        MsgBox("Please enter your Gemini API key.", "Gemini Rewrite Setup", "Iconx")
        return
    }
    status.Value := "Validating key…"
    btn.Enabled := false
    if !ValidateKey(key, ddModel.Text) {
        res := MsgBox("The API key could not be validated with " ddModel.Text ".`n`nInstall anyway?", "Gemini Rewrite Setup", "YesNo Icon!")
        if (res = "No") {
            status.Value := ""
            btn.Enabled := true
            return
        }
    }
    status.Value := "Installing…"
    try {
        DirCreate(INSTALL_DIR)
        ; Stop a running instance so the exe can be overwritten
        try RunWait('taskkill /f /im rewrite.exe', , "Hide")
        FileInstall("rewrite.exe", INSTALL_DIR "\rewrite.exe", 1)
        IniWrite(key, INSTALL_DIR "\config.ini", "Gemini", "ApiKey")
        IniWrite(ddModel.Text, INSTALL_DIR "\config.ini", "Gemini", "Model")

        lnk := A_Startup "\Gemini Rewrite.lnk"
        if cbStart.Value
            FileCreateShortcut(INSTALL_DIR "\rewrite.exe", lnk, INSTALL_DIR)
        else if FileExist(lnk)
            FileDelete(lnk)

        Run(INSTALL_DIR "\rewrite.exe", INSTALL_DIR)
    } catch Error as e {
        MsgBox("Install failed: " e.Message, "Gemini Rewrite Setup", "Iconx")
        btn.Enabled := true
        status.Value := ""
        return
    }
    MsgBox("Installed and running!`n`nSelect text anywhere and press Ctrl+Win+Alt+C.`n`nInstalled to: " INSTALL_DIR, "Gemini Rewrite Setup", "Iconi")
    ExitApp()
}

ValidateKey(key, model) {
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.SetTimeouts(10000, 10000, 10000, 10000)
        whr.Open("POST", "https://generativelanguage.googleapis.com/v1beta/models/" model ":generateContent", false)
        whr.SetRequestHeader("Content-Type", "application/json")
        whr.SetRequestHeader("x-goog-api-key", key)
        whr.Send('{"contents":[{"parts":[{"text":"hi"}]}]}')
        return whr.Status = 200 || whr.Status = 429  ; 429 = valid key, just rate-limited
    } catch {
        return true  ; offline — don't block install
    }
}
