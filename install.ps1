#!/usr/bin/env pwsh

[CmdletBinding()]
param(
    [string]$Version = "latest"
)

$ErrorActionPreference = "Stop"

$Repo = "dungngminh/simutil"
$BinaryName = "simutil.exe"
$InstallDir = Join-Path $env:LOCALAPPDATA "simutil"
$InstalledBinaryPath = Join-Path $InstallDir $BinaryName

function Write-Info {
    param([string]$Message)
    Write-Host "[info]  $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[ok]    $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[warn]  $Message" -ForegroundColor Yellow
}

function Fail {
    param([string]$Message)
    Write-Host "[err]   $Message" -ForegroundColor Red
    exit 1
}

function Resolve-Version {
    param([string]$RequestedVersion)

    if ($RequestedVersion -ne "latest") {
        return $RequestedVersion
    }

    Write-Info "Resolving latest release..."

    try {
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -Headers @{
            "Accept" = "application/vnd.github+json"
            "X-GitHub-Api-Version" = "2022-11-28"
        }
    }
    catch {
        Fail "Could not query latest release from GitHub. $_"
    }

    if (-not $release.tag_name) {
        Fail "Could not determine latest release tag."
    }

    return $release.tag_name
}

function Ensure-UserPathContainsInstallDir {
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $parts = @()

    if ($userPath) {
        $parts = $userPath -split ";"
    }

    $alreadyPresent = $parts | Where-Object { $_.TrimEnd("\") -ieq $InstallDir.TrimEnd("\") }

    # In GitHub Actions, each step starts a new process. Writing to GITHUB_PATH
    # ensures the install dir is available on PATH in subsequent steps.
    if ($env:GITHUB_PATH) {
        Add-Content -Path $env:GITHUB_PATH -Value $InstallDir
        Write-Info "Exported $InstallDir to GITHUB_PATH for CI steps"
    }

    if ($alreadyPresent) {
        Write-Info "User PATH already contains $InstallDir"
        return
    }

    $newPath = if ([string]::IsNullOrWhiteSpace($userPath)) {
        $InstallDir
    }
    else {
        "$userPath;$InstallDir"
    }

    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    $env:Path = "$env:Path;$InstallDir"
    Write-Success "Added $InstallDir to your user PATH"
}

function Install-Simutil {
    param([string]$ResolvedVersion)

    $assetName = "simutil-windows-x64.zip"
    $downloadUrl = "https://github.com/$Repo/releases/download/$ResolvedVersion/$assetName"

    Write-Info "Version:   $ResolvedVersion"
    Write-Info "Asset:     $assetName"
    Write-Info "Downloading from $downloadUrl"

    $tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("simutil-install-" + [System.Guid]::NewGuid().ToString("N"))
    $zipPath = Join-Path $tmpRoot $assetName
    $extractDir = Join-Path $tmpRoot "extract"

    New-Item -ItemType Directory -Force -Path $tmpRoot | Out-Null
    New-Item -ItemType Directory -Force -Path $extractDir | Out-Null
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath
    }
    catch {
        Remove-Item -Path $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
        Fail "Download failed. Make sure release '$ResolvedVersion' exists and includes '$assetName'."
    }

    if (-not (Test-Path $zipPath) -or ((Get-Item $zipPath).Length -le 0)) {
        Remove-Item -Path $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
        Fail "Downloaded file is missing or empty."
    }

    Write-Info "Extracting archive..."
    Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force

    $candidatePaths = @(
        (Join-Path $extractDir "simutil-windows-x64.exe"),
        (Join-Path $extractDir "simutil.exe")
    )

    $sourceBinary = $null
    foreach ($candidate in $candidatePaths) {
        if (Test-Path $candidate) {
            $sourceBinary = $candidate
            break
        }
    }

    if (-not $sourceBinary) {
        Remove-Item -Path $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
        Fail "Could not find simutil executable in extracted archive."
    }

    Copy-Item -Path $sourceBinary -Destination $InstalledBinaryPath -Force
    Remove-Item -Path $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue

    Write-Success "Installed to $InstalledBinaryPath"
}

if (-not $IsWindows) {
    Fail "This installer only supports Windows."
}

$resolved = Resolve-Version -RequestedVersion $Version
Install-Simutil -ResolvedVersion $resolved
Ensure-UserPathContainsInstallDir

Write-Host ""
Write-Success "Installation completed."
Write-Host "Run 'simutil' in a new PowerShell window."
