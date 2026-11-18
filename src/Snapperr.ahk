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
;   Double-tap Ctrl  -> snap mode ON for 10 seconds (soft sound + tiny counter).
;   Triple-tap Ctrl  -> column picker (2-9, arrows + Enter), then snap mode ON.
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
PickerValue := 4
PickerTarget := 0
TargetWindow := 0      ; tests only: window to move instead of the active one

ShortcutHelp := "
(
Turn on snap mode first:
  Double-tap Ctrl     snap mode on for 10 seconds
  Triple-tap Ctrl     pick how many columns (arrows + Enter)
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
Picker := MakePicker()

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

; Soft Windows sounds from one family: on (double-tap), columns (triple-tap), off.
Chime(name) {
    try SoundPlay(A_WinDir "\Media\" name ".wav")
}

; Tiny, see-through counter at the top of the screen. Never takes focus; clicks pass through.
MakeBadge() {
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000020")   ; no-activate + click-through
    g.BackColor := "0B2E22"
    g.MarginX := 10, g.MarginY := 3
    g.SetFont("s9 c86EFAC", "Segoe UI")
    g.label := g.Add("Text", "w92 Center", "")
    return g
}

UpdateBadge() {
    Badge.label.Text := (SplitCount ? "● " SplitCount " cols  " : "● snap  ") SnapLeft
}

ShowBadge() {
    UpdateBadge()
    MonitorGetWorkArea(ActiveMonitor(), &l, &t, &r)
    Badge.Show("NoActivate Hide AutoSize")
    Badge.GetPos(, , &bw)
    Badge.Show("NoActivate x" Round((l + r - bw) / 2) " y" (t + 8))
    WinSetTransparent(190, Badge.Hwnd)
    RoundCorners(Badge.Hwnd)
}

; Monitor that holds the middle of the active window (primary if none).
ActiveMonitor() {
    mon := MonitorGetPrimary()
    if WinExist("A") {
        WinGetPos(&wx, &wy, &ww, &wh, "A")
        Loop MonitorGetCount() {
            MonitorGet(A_Index, &l, &t, &r, &b)
            if (wx + ww / 2 >= l && wx + ww / 2 < r && wy + wh / 2 >= t && wy + wh / 2 < b)
                mon := A_Index
        }
    }
    return mon
}

RoundCorners(hwnd) {
    try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "int", 33, "int*", 2, "int", 4)
}

StartSnapMode(sound := "Speech On") {
    global SnapOn, SnapLeft
    SnapOn := true
    SnapLeft := SnapSeconds
    if sound
        Chime(sound)
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
    Chime("Speech Off")
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
        ShowPicker()
}

; ---------- column picker (triple-tap Ctrl) ----------
; A small list 2..9. Up/Down move, Enter picks, Esc cancels. Starts on 4.
; Typing 2-9 or clicking a row picks it straight away.

MakePicker() {
    g := Gui("+AlwaysOnTop -Caption +ToolWindow")
    g.BackColor := "0B1A14"
    g.MarginX := 10, g.MarginY := 10
    g.SetFont("s9 c6EE7B7", "Segoe UI")
    g.Add("Text", "w200 Center", "Columns")
    g.rows := []
    g.SetFont("s11 cD1FAE5", "Segoe UI")
    Loop 8 {
        n := A_Index + 1
        bars := ""
        Loop n
            bars .= "▮"
        row := g.Add("Text", "w200 h30 y+2 0x200 Background0B1A14", "    " n "      " bars)   ; 0x200 = centered vertically
        row.OnEvent("Click", PickerClicked.Bind(n))
        g.rows.Push(row)
    }
    g.SetFont("s8 c5F8F7A", "Segoe UI")
    g.Add("Text", "w200 Center y+8", "↑ ↓ choose   ·   Enter   ·   Esc")
    return g
}

PickerClicked(n, *) {
    PickerSelect(n)
    PickerChoose()
}

ShowPicker() {
    global PickerTarget
    PickerTarget := WinExist("A")
    Chime("Speech Disambiguation")
    PickerSelect(4)
    MonitorGetWorkArea(ActiveMonitor(), &l, &t, &r, &b)
    Picker.Show("Hide AutoSize")
    Picker.GetPos(, , &pw, &ph)
    Picker.Show("x" Round((l + r - pw) / 2) " y" Round((t + b - ph) / 2))
    RoundCorners(Picker.Hwnd)
    try WinActivate(Picker.Hwnd)
}

PickerSelect(n) {
    global PickerValue
    PickerValue := Min(9, Max(2, n))
    for i, row in Picker.rows {
        on := (i + 1 = PickerValue)
        row.Opt(on ? "+Background10B981" : "+Background0B1A14")
        row.SetFont(on ? "bold c04130C" : "norm cD1FAE5")
    }
}

PickerMove(delta) => PickerSelect(PickerValue + delta)

PickerChoose() {
    global SplitCount
    PickerClose()
    SplitCount := PickerValue
    StartSnapMode("")   ; the triple-tap sound already played
}

PickerClose() {
    Picker.Hide()
    if PickerTarget
        try WinActivate(PickerTarget)
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
    if !win || win = Badge.Hwnd || win = Picker.Hwnd
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

#HotIf WinActive("ahk_id " Picker.Hwnd)
Up::PickerMove(-1)
Down::PickerMove(1)
Enter::
NumpadEnter::PickerChoose()
Esc::PickerClose()
2::
3::
4::
5::
6::
7::
8::
9::PickerClicked(Integer(ThisHotkey))

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
