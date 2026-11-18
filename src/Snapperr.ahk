#Requires AutoHotkey v2.0
#SingleInstance Force
;@Ahk2Exe-SetName Snapperr
;@Ahk2Exe-SetDescription Snapperr - snap windows with keyboard shortcuts
;@Ahk2Exe-SetVersion 1.0.0
;@Ahk2Exe-SetCompanyName Zubair
;@Ahk2Exe-SetCopyright MIT License
;@Ahk2Exe-SetOrigFilename Snapperr.exe
;@Ahk2Exe-SetMainIcon ..\assets\snapperr.ico

; How it works:
;   Double-tap Ctrl  -> snap mode ON for 10 seconds (voice says "Snap on").
;   Triple-tap Ctrl  -> asks how many columns (2-9), then snap mode ON.
;   In snap mode (every press restarts the 10 s, Esc or double-tap Ctrl ends it):
;     Ctrl+Left / Down / Right  -> left / center / right third
;     Ctrl+L / Ctrl+;           -> left / right half
;     Ctrl+Shift+Arrow          -> move window 20 px (size stays the same)
;     Ctrl+Shift+Alt+Arrow      -> resize window 20 px (position stays the same)
;     Ctrl+1 ... Ctrl+9         -> column 1..N from the left (after a triple-tap)
;   Outside snap mode these keys do nothing, so other apps keep them.
; Does not work in apps running as administrator: Windows blocks it.

AppVersion := "1.0.0"   ; build.ps1 writes the real version here (from the VERSION file)
AppRepo := "simplyzubair/Snapperr"
AppWebsite := "https://snapperr.skillsgeek.com"
PendingUpdate := ""     ; Map from FetchUpdate() once a newer version is found
Step := 20              ; pixels per key press
MinSize := 120          ; smallest width/height when shrinking
SnapSeconds := 10       ; how long snap mode stays on after the last key
TapGap := 350           ; ms between Ctrl taps
SnapOn := false
SnapLeft := 0
SplitCount := 0         ; columns chosen with a triple-tap (0 = not chosen yet)
TapCount := 0
Voice := ""
TargetWindow := 0      ; tests only: window to move instead of the active one

ShortcutHelp := "
(
Turn on snap mode first:
  Double-tap Ctrl     snap mode on for 10 seconds
  Triple-tap Ctrl     choose how many columns, then snap mode on
  Esc                 snap mode off

Then:
  Ctrl + Left / Down / Right     left / center / right third
  Ctrl + L  /  Ctrl + ;          left / right half
  Ctrl + Shift + Arrow           move window 20 px
  Ctrl + Shift + Alt + Arrow     resize window 20 px
                                 (Right/Down = bigger, Left/Up = smaller)
  Ctrl + 1 ... Ctrl + 9          put window in that column (from the left)

Each key press keeps snap mode on for 10 more seconds.
)"

A_IconTip := "Snapperr " AppVersion
A_MaxHotkeysPerInterval := 300   ; allow holding a key down to repeat
if !A_IsCompiled && FileExist(A_ScriptDir "\..\assets\snapperr.ico")
    TraySetIcon(A_ScriptDir "\..\assets\snapperr.ico")
BuildTrayMenu()
Badge := MakeBadge()

if A_IsCompiled {
    SetTimer(StartupUpdateCheck, -8000)                 ; once, 8 s after start
    SetTimer(BackgroundUpdateCheck, 6 * 60 * 60 * 1000) ; then every 6 hours
}

; ---------- tray menu ----------

BuildTrayMenu() {
    global PendingUpdate
    m := A_TrayMenu
    m.Delete()
    if PendingUpdate {
        m.Add("Update to " PendingUpdate["version"], (*) => InstallUpdate(PendingUpdate))
        m.Add()
    }
    m.Add("Turn snap mode on", (*) => StartSnapMode())
    m.Add("Shortcuts", (*) => MsgBox(ShortcutHelp, "Snapperr " AppVersion))
    m.Add("Check for updates", (*) => ManualUpdateCheck())
    m.Add("Website", (*) => Run(AppWebsite))
    m.Add()
    m.Add("Exit", (*) => ExitApp())
    m.Default := PendingUpdate ? "Update to " PendingUpdate["version"] : "Shortcuts"
}

; ---------- updates ----------

; Returns true when a newer version was found (it is kept in PendingUpdate).
FindUpdate() {
    global PendingUpdate
    update := FetchUpdate()
    if !update
        return false
    PendingUpdate := update
    BuildTrayMenu()
    A_IconTip := "Snapperr " AppVersion " (update " update["version"] " available)"
    return true
}

AskToUpdate() {
    answer := MsgBox("Snapperr " PendingUpdate["version"] " is available. You have " AppVersion ".`n`n"
        . "Update now? It takes a few seconds.`n(You can also update later from the tray icon.)",
        "Snapperr update", 0x40024)   ; Yes/No + question icon + always on top
    if answer = "Yes"
        InstallUpdate(PendingUpdate)
}

StartupUpdateCheck() {
    try {
        if FindUpdate()
            AskToUpdate()
    }   ; offline or GitHub down: stay quiet, try again later
}

BackgroundUpdateCheck() {
    global PendingUpdate
    before := PendingUpdate ? PendingUpdate["version"] : ""
    try {
        if FindUpdate() && PendingUpdate["version"] != before
            TrayTip("Snapperr " PendingUpdate["version"] " is available. Right-click the tray icon to update.", "Snapperr")
    }
}

ManualUpdateCheck() {
    try found := FindUpdate()
    catch as e {
        MsgBox("Could not check for updates.`n`n" e.Message, "Snapperr", "Icon!")
        return
    }
    if found
        AskToUpdate()
    else
        MsgBox("You have the newest version (" AppVersion ").", "Snapperr", "Iconi")
}

#Include Updater.ahk

; ---------- snap mode ----------

; Small green popup at the top of the screen. It never takes focus and clicks pass through it.
MakeBadge() {
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000020")   ; no-activate + click-through
    g.BackColor := "0B6B4A"
    g.MarginX := 18, g.MarginY := 10
    g.SetFont("s12 bold cFFFFFF", "Segoe UI")
    g.headline := g.Add("Text", "w250 Center", "Snap on")
    g.SetFont("s9 norm cD1FAE5", "Segoe UI")
    g.hint := g.Add("Text", "w250 Center", "")
    return g
}

UpdateBadge() {
    Badge.headline.Text := "Snap on  ·  " SnapLeft " s"
    Badge.hint.Text := SplitCount
        ? "Ctrl + 1 to " SplitCount " = column   ·   Esc = off"
        : "Ctrl + arrows   ·   Esc = off"
}

ShowBadge() {
    UpdateBadge()
    mon := MonitorGetPrimary()
    if WinExist("A") {
        WinGetPos(&wx, &wy, &ww, &wh, "A")
        Loop MonitorGetCount() {
            MonitorGet(A_Index, &l, &t, &r, &b)
            if (wx + ww / 2 >= l && wx + ww / 2 < r && wy + wh / 2 >= t && wy + wh / 2 < b)
                mon := A_Index
        }
    }
    MonitorGetWorkArea(mon, &l, &t, &r)
    Badge.Show("NoActivate Hide AutoSize")
    Badge.GetPos(, , &bw)
    Badge.Show("NoActivate x" Round((l + r - bw) / 2) " y" (t + 24))
    try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", Badge.Hwnd, "int", 33, "int*", 2, "int", 4)  ; round corners
}

Say(text) {
    global Voice
    try {
        if !Voice
            Voice := ComObject("SAPI.SpVoice")
        Voice.Speak(text, 3)   ; async + stop anything still speaking
    }
}

StartSnapMode(spoken := "Snap on") {
    global SnapOn, SnapLeft
    SnapOn := true
    SnapLeft := SnapSeconds
    Say(spoken)
    ShowBadge()
    SetTimer(SnapTick, 1000)
}

SnapTick() {
    global SnapLeft
    SnapLeft -= 1
    if SnapLeft <= 0
        EndSnapMode()
    else
        UpdateBadge()
}

; Called on every snap/move/resize: keeps snap mode on for 10 more seconds.
KeepSnapModeOn() {
    global SnapLeft
    SnapLeft := SnapSeconds
    UpdateBadge()
}

EndSnapMode() {
    global SnapOn
    if !SnapOn
        return
    SnapOn := false
    SetTimer(SnapTick, 0)
    Badge.Hide()
    try SoundPlay(A_WinDir "\Media\Speech Off.wav")
}

; Ctrl taps: counts quick Ctrl presses with no other key in between.
CtrlTapped() {
    global TapCount
    static lastUp := 0
    if !(A_PriorKey ~= "^[LR]Control$") {   ; Ctrl was used with another key, e.g. Ctrl+C
        TapCount := 0
        return
    }
    TapCount := (A_TickCount - lastUp < TapGap) ? TapCount + 1 : 1
    lastUp := A_TickCount
    SetTimer(FinishTaps, -TapGap)
}

FinishTaps() {
    global TapCount
    taps := TapCount
    TapCount := 0
    if taps = 2
        SnapOn ? EndSnapMode() : StartSnapMode()
    else if taps >= 3
        AskColumns()
}

AskColumns() {
    global SplitCount
    target := WinExist("A")
    answer := InputBox("How many windows side by side? (2 to 9)", "Snapperr columns", "w300 h130", SplitCount ? SplitCount : 3)
    if target
        try WinActivate(target)
    if answer.Result != "OK"
        return
    n := Trim(answer.Value)
    if !(n ~= "^[2-9]$") {
        TrayTip("Please type a number from 2 to 9.", "Snapperr")
        return
    }
    SplitCount := Integer(n)
    StartSnapMode(n " columns")
}

; ---------- moving windows ----------

SnapWindow(xRatio, widthRatio) {
    if !win := PrepareWindow()
        return

    WinGetPos(&wx, &wy, &ww, &wh, win)
    centerX := wx + ww / 2
    centerY := wy + wh / 2

    targetMon := MonitorGetPrimary()
    Loop MonitorGetCount() {
        MonitorGet(A_Index, &mL, &mT, &mR, &mB)
        if (centerX >= mL && centerX < mR && centerY >= mT && centerY < mB) {
            targetMon := A_Index
            break
        }
    }

    MonitorGetWorkArea(targetMon, &waL, &waT, &waR, &waB)
    waWidth := waR - waL
    waHeight := waB - waT

    newX := waL + Round(waWidth * xRatio)
    newW := Round(waWidth * widthRatio)
    WinMove(newX, waT, newW, waHeight, win)
}

; Gets the active window ready to move/resize and returns its ID (0 if there is none).
; Tests set TargetWindow to their own window instead.
PrepareWindow() {
    KeepSnapModeOn()
    win := TargetWindow ? TargetWindow : WinExist("A")
    if !win || win = Badge.Hwnd
        return 0
    if WinGetMinMax(win) != 0
        WinRestore(win)
    return win
}

MoveWindow(dx, dy) {
    if !win := PrepareWindow()
        return
    WinGetPos(&x, &y, &w, &h, win)
    WinMove(x + dx, y + dy, w, h, win)
}

ResizeWindow(dw, dh) {
    if !win := PrepareWindow()
        return
    WinGetPos(&x, &y, &w, &h, win)
    WinMove(x, y, Max(MinSize, w + dw), Max(MinSize, h + dh), win)
}

SnapColumn(k) => SnapWindow((k - 1) / SplitCount, 1 / SplitCount)

; ---------- keys ----------

~LControl Up::
~RControl Up::CtrlTapped()

#HotIf SnapOn
Esc::EndSnapMode()

^Left::SnapWindow(0, 1/3)
^Down::SnapWindow(1/3, 1/3)
^Right::SnapWindow(2/3, 1/3)
^l::SnapWindow(0, 1/2)
^`;::SnapWindow(1/2, 1/2)

^+Left::MoveWindow(-Step, 0)
^+Right::MoveWindow(Step, 0)
^+Up::MoveWindow(0, -Step)
^+Down::MoveWindow(0, Step)

^+!Left::ResizeWindow(-Step, 0)
^+!Right::ResizeWindow(Step, 0)
^+!Up::ResizeWindow(0, -Step)
^+!Down::ResizeWindow(0, Step)

#HotIf SnapOn && SplitCount >= Integer(SubStr(ThisHotkey, 2))
^1::
^2::
^3::
^4::
^5::
^6::
^7::
^8::
^9::SnapColumn(Integer(SubStr(ThisHotkey, 2)))
#HotIf
