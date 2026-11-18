; Snapperr updater: checks GitHub for a newer release and installs it.
; Needs the globals AppVersion and AppRepo (set in Snapperr.ahk).

; Reads the GitHub "latest release" JSON. Returns a Map with version, url, sha256
; when that release is newer than `current`, or "" when it is not.
; Throws when the JSON has no usable version or Windows installer.
ParseLatestRelease(json, current, repo) {
    if !RegExMatch(json, '"tag_name"\s*:\s*"v?(\d+(?:\.\d+)*)"', &tag)
        throw Error("No version in the release info")
    latest := tag[1]
    if VerCompare(latest, current) <= 0
        return ""

    if !RegExMatch(json, '"name"\s*:\s*"(Snapperr-Setup-[\d.]+\.exe)"', &asset)
        throw Error("The new release has no Windows installer yet")
    prefix := "https://github.com/" repo "/releases/download/"
    if !RegExMatch(json, '"browser_download_url"\s*:\s*"([^"]+)"', &link, asset.Pos)
        || SubStr(link[1], 1, StrLen(prefix)) != prefix
        throw Error("Bad download link in the release info")

    sha := ""
    if RegExMatch(json, '"digest"\s*:\s*"sha256:([0-9a-fA-F]{64})"', &hash, asset.Pos) && hash.Pos < link.Pos
        sha := hash[1]
    return Map("version", latest, "url", link[1], "sha256", sha, "file", asset[1])
}

; Asks GitHub for the newest release. Returns the same as ParseLatestRelease.
FetchUpdate() {
    global AppVersion, AppRepo
    req := ComObject("WinHttp.WinHttpRequest.5.1")
    req.Open("GET", "https://api.github.com/repos/" AppRepo "/releases/latest", false)
    req.SetRequestHeader("User-Agent", "Snapperr/" AppVersion)
    req.SetRequestHeader("Accept", "application/vnd.github+json")
    req.SetTimeouts(5000, 5000, 5000, 10000)
    req.Send()
    if req.Status != 200
        throw Error("GitHub answered " req.Status)
    return ParseLatestRelease(req.ResponseText, AppVersion, AppRepo)
}

; SHA-256 of a file as hex, using Windows' own certutil.
FileSha256(path) {
    out := A_Temp "\snapperr-hash.txt"
    RunWait(A_ComSpec ' /c certutil -hashfile "' path '" SHA256 > "' out '"', , "Hide")
    text := FileRead(out)
    FileDelete(out)
    lines := StrSplit(text, "`n", "`r")
    return lines.Length >= 2 ? StrReplace(Trim(lines[2]), " ") : ""
}

; Downloads the installer, checks it, runs it silently and quits.
; The installer closes Snapperr, replaces it and starts the new version.
InstallUpdate(update) {
    setup := A_Temp "\" update["file"]
    TrayTip("Downloading Snapperr " update["version"] "...", "Snapperr")
    try {
        Download(update["url"], setup)
        if update["sha256"] != "" && FileSha256(setup) != update["sha256"]
            throw Error("The download is damaged (checksum does not match). Please try again.")
    } catch as e {
        try FileDelete(setup)
        MsgBox("The update failed.`n`n" e.Message, "Snapperr", "Icon!")
        return
    }
    Run('"' setup '" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART')
    ExitApp()
}
