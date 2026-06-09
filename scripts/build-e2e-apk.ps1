param(
    [switch]$Install = $false,
    [switch]$Uninstall = $false
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

if (-not $env:E2E_ASCII_WORKSPACE_ACTIVE -and $RepoRoot -match '[^\u0000-\u007F]') {
    $asciiRoot = "C:\ga-work"
    Write-Host "Non-ASCII path detected. Mirroring to ASCII workspace: $asciiRoot" -ForegroundColor Yellow

    Invoke-RobocopyMirror -Source "$RepoRoot\mobile" -Destination "$asciiRoot\mobile" -ExcludeDirs @(
        "node_modules", ".git", ".expo", "android", "build"
    )
    Invoke-RobocopyMirror -Source "$RepoRoot\automation" -Destination "$asciiRoot\automation" -ExcludeDirs @(
        "node_modules", ".git", "coverage", "screenshots"
    )

    $env:E2E_ASCII_WORKSPACE_ACTIVE = "1"

    $nextScript = "$asciiRoot\automation\scripts\build-e2e-apk.ps1"
    & $nextScript -Install:$Install -Uninstall:$Uninstall
    exit $LASTEXITCODE
}

$ProjectRoot = (Resolve-Path "$PSScriptRoot\..\..\mobile").Path

Write-Host "Building E2E APK..." -ForegroundColor Cyan
Write-Host "Project root: $ProjectRoot" -ForegroundColor Gray

Write-Host "Generating native Android project..." -ForegroundColor Cyan
Push-Location $ProjectRoot
try {
    $env:CI = "1"
    $env:EXPO_NO_GIT_STATUS = "1"
    npx expo prebuild --platform android --clean --no-install
    if ($LASTEXITCODE -ne 0) {
        throw "expo prebuild failed with exit code $LASTEXITCODE"
    }
    Write-Host "Native Android project generated" -ForegroundColor Green
}
finally {
    Pop-Location
}

Write-Host "Building APK with Gradle..." -ForegroundColor Cyan
$gradlewPath = Join-Path $ProjectRoot "android\gradlew.bat"
$gradlePropsPath = Join-Path $ProjectRoot "android\gradle.properties"
if (-not (Test-Path $gradlewPath)) {
    throw "gradlew not found at $gradlewPath"
}

if (Test-Path $gradlePropsPath) {
    $gradlePropsContent = Get-Content $gradlePropsPath -Raw
    if ($gradlePropsContent -notmatch "(?m)^android\.overridePathCheck=true$") {
        Add-Content -Path $gradlePropsPath -Value "`nandroid.overridePathCheck=true"
        Write-Host "Added android.overridePathCheck=true to gradle.properties" -ForegroundColor Yellow
    }
}

Push-Location (Join-Path $ProjectRoot "android")
try {
    & $gradlewPath "-Dandroid.overridePathCheck=true" assembleRelease --stacktrace
    if ($LASTEXITCODE -ne 0) {
        throw "Gradle build failed with exit code $LASTEXITCODE"
    }
    Write-Host "APK built successfully" -ForegroundColor Green
}
finally {
    Pop-Location
}

$apkPath = Join-Path $ProjectRoot "android\app\build\outputs\apk\release\app-release.apk"
if (-not (Test-Path $apkPath)) {
    throw "APK not found at $apkPath"
}

$apkSizeMb = [math]::Round(((Get-Item $apkPath).Length / 1MB), 2)
Write-Host "APK ready: $apkPath" -ForegroundColor Green
Write-Host "File size: $apkSizeMb MB" -ForegroundColor Gray

if ($Install) {
    Write-Host "Installing APK to device..." -ForegroundColor Cyan
    $adbPath = "adb"
    $sdkAdbPath = "C:\Users\conta\AppData\Local\Android\Sdk\platform-tools\adb.exe"
    if (Test-Path $sdkAdbPath) {
        $adbPath = $sdkAdbPath
    }

    if ($Uninstall) {
        Write-Host "Uninstalling old version..." -ForegroundColor Yellow
        & $adbPath uninstall "com.guiaaventureiro.app" 2>$null
    }

    & $adbPath install -r "$apkPath"
    if ($LASTEXITCODE -ne 0) {
        throw "APK installation failed with exit code $LASTEXITCODE"
    }

    Write-Host "APK installed successfully" -ForegroundColor Green
}

Write-Host "Next step: npm run e2e:android" -ForegroundColor Cyan
