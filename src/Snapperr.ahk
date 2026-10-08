#Requires AutoHotkey v2.0
#SingleInstance Force
;@Ahk2Exe-SetName Snapperr
;@Ahk2Exe-SetDescription Snapperr - snap windows with keyboard shortcuts
;@Ahk2Exe-SetVersion 1.0.0
;@Ahk2Exe-SetCompanyName Zubair
;@Ahk2Exe-SetCopyright MIT License
;@Ahk2Exe-SetOrigFilename Snapperr.exe

; Shortcuts:
;   Ctrl+Left   -> left third
;   Ctrl+Down   -> center third
;   Ctrl+Right  -> right third
;   Ctrl+L      -> left half
;   Ctrl+;      -> right half
; Does not work in apps running as administrator: Windows blocks it.

ShortcutHelp := "
(
Snapperr shortcuts:

Ctrl + Left     left third
Ctrl + Down     center third
Ctrl + Right    right third
Ctrl + L        left half
Ctrl + ;        right half
)"

A_IconTip := "Snapperr"
A_TrayMenu.Delete()
A_TrayMenu.Add("Shortcuts", (*) => MsgBox(ShortcutHelp, "Snapperr"))
A_TrayMenu.Add()
A_TrayMenu.Add("Exit", (*) => ExitApp())
A_TrayMenu.Default := "Shortcuts"

SnapWindow(xRatio, widthRatio) {
    if !WinExist("A")
        return
    if WinGetMinMax("A") != 0
        WinRestore("A")

    WinGetPos(&wx, &wy, &ww, &wh, "A")
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
    WinMove(newX, waT, newW, waHeight, "A")
}

^Left::SnapWindow(0, 1/3)
^Down::SnapWindow(1/3, 1/3)
^Right::SnapWindow(2/3, 1/3)
^l::SnapWindow(0, 1/2)
^`;::SnapWindow(1/2, 1/2)
