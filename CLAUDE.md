# Snapperr (repo simplyzubair/Snapperr, public, default branch main)

- Keyboard window snapping. Windows app = AutoHotkey v2 (`src/`), Mac app = Swift menu bar app (`mac/main.swift`). Keep features the same on both.
- Keys only work in snap mode (double-tap Ctrl, 10 s, restarted by every key; triple-tap = column picker list 2-9, starts on 4). Owner decisions 2026-11-18/19: no voice, only soft sounds (Windows Speech On / Disambiguation / Off, Mac Tink / Purr / Pop), tiny see-through counter.
- Version lives in `VERSION` only. Pushing a new number to `main` makes `.github/workflows/release.yml` publish `v<VERSION>` with `Snapperr-Setup-<v>.exe` and `Snapperr-<v>-mac.dmg`. Installed apps auto-update from the GitHub "latest release" (file names must keep that pattern). Never hand-tag.
- Website: https://snapperr.skillsgeek.com, `bash scripts/deploy-website.sh` (host nginx on `co`, `/var/www/snapperr`, certbot HTTPS, Cloudflare DNS only). Config copy in `deploy/`.
- Local Windows tools live in `tools/` (git-ignored): AutoHotkey 2.0.31, Ahk2Exe, Inno Setup 7. Before pushing run both `tests/*.ahk`.
- mini-pc-6's Windows session is usually disconnected: fake key presses don't reach hotkeys and no window is "active". Tests therefore call functions directly and set `TargetWindow`. Never let a test send keys to or move the user's own windows.
- Mac is built only in CI (macos-latest); nothing here can compile Swift.
