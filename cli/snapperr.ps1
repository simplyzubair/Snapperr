# Snapperr command line: installs and updates the Snapperr app (Windows).
#   snapperr install   install Snapperr, or update it if it is old
#   snapperr update    same as install
#   snapperr version   show the installed and the newest version
param([string]$Command = "help")
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12   # PowerShell 5.1 default is too old for GitHub
$Repo = "simplyzubair/Snapperr"
$AppExe = "$env:LOCALAPPDATA\Programs\Snapperr\Snapperr.exe"

function Get-Installed {
    if (Test-Path $AppExe) { return [version](Get-Item $AppExe).VersionInfo.FileVersion }
    return $null
}

function Get-Latest {
    $r = Invoke-RestMethod "https://api.github.com/repos/$Repo/releases/latest" -Headers @{ "User-Agent" = "snapperr-cli" }
    $asset = $r.assets | Where-Object { $_.name -match '^Snapperr-Setup-[\d.]+\.exe$' } | Select-Object -First 1
    if (-not $asset) { throw "The newest release has no Windows installer yet. Try again in a few minutes." }
    if ($asset.digest -notmatch '^sha256:([0-9a-fA-F]{64})$') { throw "The newest release has no checksum, so it cannot be checked." }
    [pscustomobject]@{ Version = [version]($r.tag_name -replace '^v'); Url = $asset.browser_download_url; Sha256 = $Matches[1]; File = $asset.name }
}

function Install-Latest {
    $have = Get-Installed
    $new = Get-Latest
    if ($have -and $have -ge $new.Version) { "Snapperr $have is already the newest version."; return }
    if (-not $new.Url.StartsWith("https://github.com/$Repo/releases/download/")) { throw "Bad download link: $($new.Url)" }
    $setup = Join-Path $env:TEMP $new.File
    "Downloading Snapperr $($new.Version)..."
    Invoke-WebRequest $new.Url -OutFile $setup -UseBasicParsing
    try {
        if ((Get-FileHash $setup -Algorithm SHA256).Hash -ne $new.Sha256.ToUpper()) { throw "The download is damaged (checksum does not match). Please try again." }
        "Installing..."
        $p = Start-Process $setup -ArgumentList "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART" -PassThru
        $p.WaitForExit()   # not -Wait: it would also wait for the Snapperr.exe the installer starts
        if ($p.ExitCode -ne 0) { throw "The installer failed (exit code $($p.ExitCode))." }
    } finally { Remove-Item $setup -ErrorAction SilentlyContinue }
    if ($have) { "Updated Snapperr $have -> $($new.Version)." } else { "Installed Snapperr $($new.Version). It starts by itself when you sign in." }
}

trap {
    $m = "$_"
    if ($m -match "rate limit") { $m = "GitHub is busy for this network (too many checks this hour). Please try again later." }
    Write-Host "Snapperr: $m" -ForegroundColor Red
    exit 1
}

switch ($Command) {
    { $_ -in "install", "update" } { Install-Latest }
    "version" {
        $have = Get-Installed
        "Installed: " + $(if ($have) { $have } else { "not installed" })
        "Newest:    " + (Get-Latest).Version
    }
    default {
        "Snapperr command line"
        "  snapperr install   install Snapperr, or update it if it is old"
        "  snapperr update    same as install"
        "  snapperr version   show the installed and the newest version"
    }
}
