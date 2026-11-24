; Tests snap mode and window moving by calling Snapperr's functions directly
; (works even with no one at the screen). Run:
;   tools\AutoHotkey\AutoHotkey64.exe /ErrorStdOut tests\snap_test.ahk
#Requires AutoHotkey v2.0
OnError((e, *) => (FileAppend("ERROR " e.Message " (line " e.Line ")`n", "*"), ExitApp(2)))
#Include ..\src\Snapperr.ahk

Fails := 0
Check(name, ok, info := "") {
    global Fails
    FileAppend((ok ? "PASS " : "FAIL ") name (info != "" ? "  [" info "]" : "") "`n", "*")
    Fails += !ok
}
Pos() {
    WinGetPos(&x, &y, &w, &h, TestWin.Hwnd)
    return {x: x, y: y, w: w, h: h}
}
Near(a, b) => Abs(a - b) <= 16

TestWin := Gui("+Resize", "SnapperrTestWindow")
TestWin.Show("x300 y200 w500 h400")
TargetWindow := TestWin.Hwnd   ; no one is at the screen in CI, so nothing can be "active"

MonitorGetWorkArea(MonitorGetPrimary(), &l, &t, &r, &b)
W := r - l

Check("snap mode starts off", !SnapOn)
TapCount := 2, FinishTaps()
Check("double tap turns snap mode on", SnapOn && SnapLeft = 10)
Check("popup is visible", DllCall("IsWindowVisible", "ptr", Badge.Hwnd))
Check("popup did not take focus", !WinActive(Badge.Hwnd))

SnapLeft := 3
SnapWindow(0, 1/3), q := Pos()
Check("left third", Near(q.x, l) && Near(q.w, W / 3) && Near(q.h, b - t), q.x "," q.w "," q.h)
Check("a key press restarts the 10 s", SnapLeft = 10)
SnapWindow(2/3, 1/3), q := Pos()
Check("right third", Near(q.x + q.w, r), q.x "," q.w)
SnapWindow(1/2, 1/2), q := Pos()
Check("right half", Near(q.x, l + W / 2) && Near(q.w, W / 2), q.x "," q.w)
SnapWindow(0, 1), q := Pos()
Check("full screen (Ctrl+F)", Near(q.x, l) && Near(q.w, W) && Near(q.h, b - t), q.x "," q.w "," q.h)

p := Pos(), MoveWindow(Step, 0), q := Pos()
Check("move right 20 px, size same", q.x - p.x = 20 && q.y = p.y && q.w = p.w && q.h = p.h)
p := Pos(), MoveWindow(0, -Step), q := Pos()
Check("move up 20 px", p.y - q.y = 20 && q.x = p.x)
p := Pos(), ResizeWindow(Step, 0), q := Pos()
Check("resize wider 20 px, place same", q.w - p.w = 20 && q.x = p.x && q.y = p.y && q.h = p.h)
p := Pos(), ResizeWindow(0, -Step), q := Pos()
Check("resize shorter 20 px", p.h - q.h = 20 && q.y = p.y)
WinMove(, , 130, 130, TestWin.Hwnd)
ResizeWindow(-Step, -Step), q := Pos()
Check("never smaller than " MinSize " px", q.w >= MinSize && q.h >= MinSize, q.w "x" q.h)

SplitCount := 4
SnapColumn(2), q := Pos()
Check("column 2 of 4", Near(q.x, l + W / 4) && Near(q.w, W / 4), q.x "," q.w)
SplitCount := 7
SnapColumn(7), q := Pos()
Check("column 7 of 7 ends at the right edge", Near(q.x + q.w, r) && Near(q.w, W / 7), q.x "," q.w)

WinMaximize(TestWin.Hwnd)
MoveWindow(Step, 0)
Check("maximized window is restored first", WinGetMinMax(TestWin.Hwnd) = 0)

TapCount := 2, FinishTaps()
Check("double tap again turns it off", !SnapOn && !DllCall("IsWindowVisible", "ptr", Badge.Hwnd))
StartSnapMode()
SnapLeft := 1, SnapTick()
Check("turns off by itself when time is up", !SnapOn)
StartSnapMode(), EndSnapMode()
Check("Esc handler turns it off", !SnapOn)

TapCount := 1, FinishTaps()
Check("single tap does nothing", !SnapOn)

TapCount := 3, FinishTaps()
Check("triple tap opens the column picker", DllCall("IsWindowVisible", "ptr", Picker.Hwnd))
Check("picker starts on 4", PickerValue = 4)
PickerMove(-1)
Check("Up selects 3", PickerValue = 3)
Loop 10
    PickerMove(1)
Check("Down stops at 9", PickerValue = 9)
Loop 10
    PickerMove(-1)
Check("Up stops at 2", PickerValue = 2)
PickerMove(1), PickerMove(1), PickerMove(1)
PickerChoose()
Check("Enter picks 5 columns and turns snap mode on", SplitCount = 5 && SnapOn && !DllCall("IsWindowVisible", "ptr", Picker.Hwnd), SplitCount)
Check("counter shows the columns", InStr(Badge.label.Text, "5 cols"), Badge.label.Text)
EndSnapMode()
TapCount := 3, FinishTaps()
Check("picker opens on 4 again", PickerValue = 4)
PickerClose()
Check("Esc closes the picker without changes", SplitCount = 5 && !SnapOn && !DllCall("IsWindowVisible", "ptr", Picker.Hwnd))
TapCount := 3, FinishTaps()
PickerClicked(7)
Check("typing or clicking 7 picks 7", SplitCount = 7 && SnapOn)
EndSnapMode()

FileAppend(Fails ? Fails " test(s) failed`n" : "All tests passed`n", "*")
ExitApp(Fails ? 1 : 0)
