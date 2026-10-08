param([string]$Version = "1.0.0")
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$ahk2exe = "$PSScriptRoot\tools\Ahk2Exe\Ahk2Exe.exe"
$base    = "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe"
$iscc    = "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"

New-Item -ItemType Directory -Force build, dist | Out-Null

(Get-Content src\Snapperr.ahk -Raw) -replace ';@Ahk2Exe-SetVersion .*', ";@Ahk2Exe-SetVersion $Version" |
    Set-Content src\Snapperr.ahk -NoNewline

& $ahk2exe /in src\Snapperr.ahk /out build\Snapperr.exe /base $base /silent verbose | Out-Host
if (-not (Test-Path build\Snapperr.exe)) { throw "Ahk2Exe failed" }

& $iscc /Q "/DAppVersion=$Version" installer\Snapperr.iss
if ($LASTEXITCODE -ne 0) { throw "Inno Setup failed" }

$setup = "dist\Snapperr-Setup-$Version.exe"
"Built $setup"
"SHA256: " + (Get-FileHash $setup -Algorithm SHA256).Hash
