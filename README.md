# Snapperr

Snap any window into place with one keyboard shortcut. Windows only.

| Shortcut | Window goes to |
|---|---|
| `Ctrl + Left` | left third |
| `Ctrl + Down` | center third |
| `Ctrl + Right` | right third |
| `Ctrl + L` | left half |
| `Ctrl + ;` | right half |

Works on the monitor the window is on. Starts automatically when you sign in to Windows.

## Install

```
winget install Zubair.Snapperr
```

Or download `Snapperr-Setup-<version>.exe` from [Releases](https://github.com/simplyzubair/Snapperr/releases) and run it. No admin rights needed.

## Use

- A tray icon shows Snapperr is running. Right-click it for **Shortcuts** or **Exit**.
- To uninstall: Windows **Settings > Apps > Installed apps > Snapperr > Uninstall**, or `winget uninstall Zubair.Snapperr`.

## Limits

- Does not work while an app running **as administrator** is active (for example RustDesk). Windows blocks normal programs from controlling admin windows.
- The program is not code-signed, so Windows SmartScreen may warn on first install. Click **More info > Run anyway**.

## Build from source

Needs [AutoHotkey v2](https://www.autohotkey.com/), [Ahk2Exe](https://github.com/AutoHotkey/Ahk2Exe/releases) in `tools\Ahk2Exe\`, and [Inno Setup 6](https://jrsoftware.org/isinfo.php).

```
powershell -ExecutionPolicy Bypass -File build.ps1 -Version 1.0.0
```

Output: `dist\Snapperr-Setup-1.0.0.exe`.

| Path | What it is |
|---|---|
| `src\Snapperr.ahk` | the program |
| `installer\Snapperr.iss` | installer script (Inno Setup) |
| `winget\` | winget manifest files |
| `dist\` | built installers |

## License

MIT
