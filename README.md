<p align="center"><img src="assets/snapperr.png" width="128" alt="Snapperr icon"></p>

# Snapperr

Snap any window into place with your keyboard. Windows and Mac.

Download: **https://snapperr.skillsgeek.com**

## How it works

Snapperr's keys only work in **snap mode**, so they never get in the way of your other apps.

| Keys | What happens |
|---|---|
| Double-tap `Ctrl` | Snap mode on for 10 seconds. A voice says "Snap on" and a small popup counts down. |
| Triple-tap `Ctrl` | Asks how many columns (2 to 9), then snap mode on. |
| `Esc` (or double-tap `Ctrl` again) | Snap mode off |

While snap mode is on (every key press adds 10 more seconds):

| Keys | Window goes to |
|---|---|
| `Ctrl + Left` / `Down` / `Right` | left / center / right third |
| `Ctrl + L` / `Ctrl + ;` | left / right half |
| `Ctrl + 1` … `Ctrl + 9` | column 1 … N from the left (after a triple-tap) |
| `Ctrl + Shift + Arrow` | moves 20 px (size stays the same) |
| `Ctrl + Shift + Alt + Arrow` | resizes 20 px: Right/Down bigger, Left/Up smaller (position stays the same) |

Hold the move/resize keys down to keep going. Works on the monitor the window is on. On Mac, `Alt` is `Option`.

## Install

**Windows:** download `Snapperr-Setup-<version>.exe` from the website and run it. No admin rights needed. It starts when you sign in.

**Mac (preview):** open `Snapperr-<version>-mac.dmg` and drag Snapperr into Applications. It is not signed by Apple: the first time, go to **System Settings → Privacy & Security → Open Anyway**. Then allow **Accessibility** when asked. If `Ctrl + Left/Right` switches desktops, turn that off in **System Settings → Keyboard → Keyboard Shortcuts → Mission Control**.

## Updates

Snapperr checks GitHub for a new version 8 seconds after it starts and every 6 hours.

- At start it asks **"Update now?"**. Yes downloads, checks and installs it, then restarts Snapperr.
- Or right-click the tray icon (Mac: click the menu bar icon) → **Update to x.y.z** / **Check for updates**.
- Mac: after an update, macOS may ask for Accessibility access again (the app is not signed by Apple).

## Limits

- Windows: does not work while an app running **as administrator** is active (for example RustDesk). Windows blocks normal programs from controlling admin windows.
- Not code-signed, so Windows SmartScreen may warn on first install. Click **More info > Run anyway**.

## Releasing a new version

1. Change the number in `VERSION` (for example `1.2.0`).
2. Push to `main`. GitHub Actions runs the tests, builds the Windows `.exe` and Mac `.dmg`, and publishes release `v1.2.0`.
3. Installed apps find it by themselves. The website links to it by itself.

## Build on your own PC

**Windows** needs [AutoHotkey v2](https://www.autohotkey.com/) (`tools\AutoHotkey\`), [Ahk2Exe](https://github.com/AutoHotkey/Ahk2Exe/releases) (`tools\Ahk2Exe\`) and [Inno Setup](https://jrsoftware.org/isinfo.php) (`tools\InnoSetup\` or installed). `tools\` is not in git.

```
powershell -ExecutionPolicy Bypass -File build.ps1
tools\AutoHotkey\AutoHotkey64.exe /ErrorStdOut tests\updater_test.ahk
tools\AutoHotkey\AutoHotkey64.exe /ErrorStdOut tests\snap_test.ahk
```

**Mac** needs the Xcode command line tools: `bash mac/build.sh`

| Path | What it is |
|---|---|
| `VERSION` | the version number for both apps |
| `src\Snapperr.ahk`, `src\Updater.ahk` | the Windows app (AutoHotkey v2) |
| `mac\main.swift` | the Mac app (Swift) |
| `tests\` | Windows tests |
| `assets\` | icons (`make_icon.py` redraws them) |
| `installer\Snapperr.iss` | Windows installer script (Inno Setup) |
| `website\` | download page, deployed with `bash scripts/deploy-website.sh` |
| `.github\workflows\release.yml` | builds and releases |
| `winget\` | winget manifest files |

## License

MIT
