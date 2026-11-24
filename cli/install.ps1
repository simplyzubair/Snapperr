# One-line setup for the Snapperr command line (Windows). In PowerShell:
#   irm https://snapperr.skillsgeek.com/install.ps1 | iex
# Puts the "snapperr" command in %LOCALAPPDATA%\Programs\Snapperr-cli (no admin),
# adds it to your PATH, then installs or updates the Snapperr app.
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$dir = "$env:LOCALAPPDATA\Programs\Snapperr-cli"
New-Item -ItemType Directory -Force $dir | Out-Null
Invoke-WebRequest "https://snapperr.skillsgeek.com/snapperr.ps1" -OutFile "$dir\snapperr.ps1" -UseBasicParsing
Set-Content "$dir\snapperr.cmd" '@powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0snapperr.ps1" %*' -Encoding Ascii

$path = [Environment]::GetEnvironmentVariable("Path", "User")
if (($path -split ";") -notcontains $dir) {
    [Environment]::SetEnvironmentVariable("Path", ($(if ($path) { "$path;" }) + $dir), "User")
}
if (($env:Path -split ";") -notcontains $dir) { $env:Path += ";$dir" }

& powershell -NoProfile -ExecutionPolicy Bypass -File "$dir\snapperr.ps1" install
"The 'snapperr' command is ready (open a new terminal to use it): snapperr update / snapperr version"
