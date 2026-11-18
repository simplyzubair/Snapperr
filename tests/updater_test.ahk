; Tests for ParseLatestRelease. Run:
;   tools\AutoHotkey\AutoHotkey64.exe /ErrorStdOut tests\updater_test.ahk
; Prints PASS/FAIL lines and exits 1 if anything failed.
#Requires AutoHotkey v2.0
#NoTrayIcon
#Warn All, StdOut
AppVersion := "0", AppRepo := ""   ; Updater.ahk expects these globals
#Include ..\src\Updater.ahk
OnError((e, *) => (FileAppend("ERROR " e.Message " (line " e.Line ")`n", "*"), ExitApp(2)))

Fails := 0
Check(name, ok) {
    global Fails
    FileAppend((ok ? "PASS " : "FAIL ") name "`n", "*")
    if !ok
        Fails += 1
}
Throws(fn) {
    try fn()
    catch
        return true
    return false
}

repo := "simplyzubair/Snapperr"
sha := "ab12" . "0123456789abcdef0123456789abcdef0123456789abcdef0123456789ab"
json := '{"tag_name":"v1.2.0","name":"Snapperr 1.2.0","assets":['
    . '{"name":"Snapperr-1.2.0-mac.dmg","digest":"sha256:' StrReplace(sha, "a", "c") '",'
    . '"browser_download_url":"https://github.com/simplyzubair/Snapperr/releases/download/v1.2.0/Snapperr-1.2.0-mac.dmg"},'
    . '{"name":"Snapperr-Setup-1.2.0.exe","uploader":{"login":"x"},"digest":"sha256:' sha '",'
    . '"browser_download_url":"https://github.com/simplyzubair/Snapperr/releases/download/v1.2.0/Snapperr-Setup-1.2.0.exe"}]}'

u := ParseLatestRelease(json, "1.1.0", repo)
Check("newer version found", IsObject(u) && u["version"] = "1.2.0")
Check("picks the Windows installer", u["url"] = "https://github.com/simplyzubair/Snapperr/releases/download/v1.2.0/Snapperr-Setup-1.2.0.exe")
Check("picks the installer's own checksum", u["sha256"] = sha)
Check("same version is not an update", ParseLatestRelease(json, "1.2.0", repo) = "")
Check("older release is not an update", ParseLatestRelease(json, "1.10.0", repo) = "")
Check("1.10.0 is newer than 1.9.0", IsObject(ParseLatestRelease(StrReplace(json, "v1.2.0", "v1.10.0", , , 1), "1.9.0", repo)))

noDigest := RegExReplace(json, '"digest":"[^"]*",')
Check("works without checksum", ParseLatestRelease(noDigest, "1.0.0", repo)["sha256"] = "")
Check("only mac file -> error", Throws(() => ParseLatestRelease('{"tag_name":"v2.0.0","assets":[{"name":"Snapperr-2.0.0-mac.dmg","browser_download_url":"https://github.com/simplyzubair/Snapperr/releases/download/v2.0.0/Snapperr-2.0.0-mac.dmg"}]}', "1.0.0", repo)))
Check("foreign link -> error", Throws(() => ParseLatestRelease(StrReplace(json, "https://github.com/simplyzubair/Snapperr/releases/download/v1.2.0/Snapperr-Setup", "https://evil.example/Snapperr-Setup"), "1.0.0", repo)))
Check("no tag -> error", Throws(() => ParseLatestRelease('{"message":"Not Found"}', "1.0.0", repo)))

FileAppend(Fails ? Fails " test(s) failed`n" : "All tests passed`n", "*")
ExitApp(Fails ? 1 : 0)
