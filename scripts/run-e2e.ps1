param(
    [switch]$SkipBuild = $false,
    [switch]$SkipInstall = $false
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path "$PSScriptRoot\..\..").Path

function Invoke-RobocopyMirror {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination,
        [string[]]$ExcludeDirs = @()
    )

    $destParent = Split-Path -Parent $Destination
    if (-not (Test-Path $destParent)) {
        New-Item -ItemType Directory -Path $destParent -Force | Out-Null
    }

    $robocopyArgs = @(
        $Source,
        $Destination,
        "*.*",
        "/MIR",
        "/R:2",
        "/W:2",
        "/NFL",
        "/NDL",
        "/NJH",
        "/NJS",
        "/NP",
        "/XD"
    ) + $ExcludeDirs

    & robocopy @robocopyArgs | Out-Null
    if ($LASTEXITCODE -ge 8) {
        throw "robocopy failed from '$Source' to '$Destination' with exit code $LASTEXITCODE"
    }
}

function Ensure-NpmDependencies {
    param(
        [Parameter(Mandatory = $true)][string]$Directory,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $nodeModulesPath = Join-Path $Directory "node_modules"
    if (Test-Path $nodeModulesPath) {
        return
    }

    Write-Host "Installing npm dependencies for $Label..." -ForegroundColor Yellow
    Push-Location $Directory
    try {
        npm ci --no-audit --no-fund --no-progress
        if ($LASTEXITCODE -ne 0) {
            throw "npm ci failed for $Label with exit code $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }
}

if (-not $env:E2E_ASCII_WORKSPACE_ACTIVE -and $RepoRoot -match '[^\u0000-\u007F]') {
    $asciiRoot = "C:\ga-work"
    Write-Host "Non-ASCII path detected. Mirroring to ASCII workspace: $asciiRoot" -ForegroundColor Yellow

    Invoke-RobocopyMirror -Source "$RepoRoot\mobile" -Destination "$asciiRoot\mobile" -ExcludeDirs @(
        "node_modules", ".git", ".expo", "android", "build"
    )
    Invoke-RobocopyMirror -Source "$RepoRoot\automation" -Destination "$asciiRoot\automation" -ExcludeDirs @(
        "node_modules", ".git", "coverage", "screenshots"
    )

    Ensure-NpmDependencies -Directory "$asciiRoot\mobile" -Label "mobile"
    Ensure-NpmDependencies -Directory "$asciiRoot\automation" -Label "automation"

    $env:E2E_ASCII_WORKSPACE_ACTIVE = "1"

    $nextScript = "$asciiRoot\automation\scripts\run-e2e.ps1"
    & $nextScript -SkipBuild:$SkipBuild -SkipInstall:$SkipInstall
    exit $LASTEXITCODE
}

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$AutomationRoot = (Resolve-Path "$ScriptRoot\..").Path
$MobileRoot = (Resolve-Path "$ScriptRoot\..\..\mobile").Path

Ensure-NpmDependencies -Directory $MobileRoot -Label "mobile"
Ensure-NpmDependencies -Directory $AutomationRoot -Label "automation"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  E2E Testing Workflow" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Step 1: Build
if (-not $SkipBuild) {
    Write-Host "`n[1/3] Building E2E APK..." -ForegroundColor Cyan
    & "$ScriptRoot\build-e2e-apk.ps1" -Install:(-not $SkipInstall)

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Build failed" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "[1/3] Skipping build (APK already built)" -ForegroundColor Gray
}

# Step 2: Install (if not done by build script)
if (-not $SkipInstall -and $SkipBuild) {
    Write-Host "`n[2/3] Installing APK to device..." -ForegroundColor Cyan

    $apkPath = "$((Resolve-Path "$ScriptRoot\..\..\mobile").Path)\android\app\build\outputs\apk\release\app-release.apk"

    if (-not (Test-Path $apkPath)) {
        Write-Host "APK not found at $apkPath - run build first" -ForegroundColor Red
        exit 1
    }

    adb install -r $apkPath

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Installation failed" -ForegroundColor Red
        exit 1
    }

    Write-Host "Installation complete" -ForegroundColor Green
} else {
    Write-Host "[2/3] Skipping installation" -ForegroundColor Gray
}

# Step 3: Run tests
Write-Host "`n[3/3] Running E2E regression tests..." -ForegroundColor Cyan
Push-Location $AutomationRoot
try {
    npm run e2e:android
    $testResult = $LASTEXITCODE
} finally {
    Pop-Location
}

Write-Host "`n========================================" -ForegroundColor Cyan
if ($testResult -eq 0) {
    Write-Host "All tests passed" -ForegroundColor Green
} else {
    Write-Host "Tests failed (exit code: $testResult)" -ForegroundColor Red
}
Write-Host "========================================" -ForegroundColor Cyan

exit $testResult
