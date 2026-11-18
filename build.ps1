# Builds dist\Snapperr-Setup-<version>.exe (Windows).
# The version comes from the VERSION file unless you pass -Version.
# Tools are looked up in tools\ first (see README), then in the usual install folders.
param([string]$Version = "")
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
if (-not $Version) { $Version = (Get-Content VERSION -Raw).Trim() }

function Find-Tool($name, $paths) {
    foreach ($p in $paths) { if ($p -and (Test-Path $p)) { return (Resolve-Path $p).Path } }
    throw "$name not found. Looked in:`n  " + ($paths -join "`n  ")
}
$ahk2exe = Find-Tool "Ahk2Exe" @("tools\Ahk2Exe\Ahk2Exe.exe", "$env:ProgramFiles\AutoHotkey\Compiler\Ahk2Exe.exe")
$base    = Find-Tool "AutoHotkey v2" @("tools\AutoHotkey\AutoHotkey64.exe", "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe", "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe")
$iscc    = Find-Tool "Inno Setup" @("tools\InnoSetup\ISCC.exe", "$env:LOCALAPPDATA\Programs\Inno Setup 7\ISCC.exe", "${env:ProgramFiles(x86)}\Inno Setup 7\ISCC.exe", "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe", "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe")

New-Item -ItemType Directory -Force build\src, dist | Out-Null

# Copy the source with the version filled in, so src\ is never changed by a build.
(Get-Content src\Snapperr.ahk -Raw) `
    -replace ';@Ahk2Exe-SetVersion .*', ";@Ahk2Exe-SetVersion $Version" `
    -replace 'AppVersion := "[^"]*"', "AppVersion := `"$Version`"" |
    Set-Content build\src\Snapperr.ahk -NoNewline -Encoding utf8
Copy-Item src\Updater.ahk build\src\Updater.ahk -Force

Remove-Item build\Snapperr.exe -ErrorAction SilentlyContinue
# build\src is two levels below the repo, like src\, so ..\assets\snapperr.ico still works.
New-Item -ItemType Directory -Force build\assets | Out-Null
Copy-Item assets\snapperr.ico build\assets\snapperr.ico -Force
$p = Start-Process $ahk2exe -ArgumentList "/in", "build\src\Snapperr.ahk", "/out", "build\Snapperr.exe", "/base", "`"$base`"", "/silent", "verbose" -Wait -PassThru -NoNewWindow
if ($p.ExitCode -ne 0 -or -not (Test-Path build\Snapperr.exe)) { throw "Ahk2Exe failed (exit $($p.ExitCode))" }

& $iscc /Q "/DAppVersion=$Version" installer\Snapperr.iss
if ($LASTEXITCODE -ne 0) { throw "Inno Setup failed" }

$setup = "dist\Snapperr-Setup-$Version.exe"
"Built $setup"
"SHA256: " + (Get-FileHash $setup -Algorithm SHA256).Hash
