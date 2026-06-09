param(
    [string]$ApiUrl = "https://guia-aventureiro-api-new.onrender.com",
    [string]$AdbSerial,
    [string]$AppPackage = "com.guiaaventureiro.app",
    [switch]$SkipBuild = $false,
    [switch]$SkipInstall = $false,
    [switch]$NoApiHealthcheck = $false
)

$ErrorActionPreference = "Stop"

function Get-AdbPath {
    $candidates = @(
        "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
        "$env:ANDROID_HOME\platform-tools\adb.exe",
        "$env:ANDROID_SDK_ROOT\platform-tools\adb.exe"
    ) | Where-Object { $_ -and (Test-Path $_) }

    if ($candidates.Count -gt 0) {
        return $candidates[0]
    }

    return "adb"
}

function Assert-ApiHealthy {
    param([Parameter(Mandatory = $true)][string]$BaseUrl)

    $healthUrl = "$($BaseUrl.TrimEnd('/'))/api/auth/signup"
    try {
        $response = Invoke-WebRequest -UseBasicParsing -Method Options -Uri $healthUrl -TimeoutSec 25
        if ($response.StatusCode -lt 200 -or $response.StatusCode -ge 500) {
            throw "API respondeu com status inesperado: $($response.StatusCode)"
        }
        Write-Host "API OK ($($response.StatusCode)): $healthUrl" -ForegroundColor Green
    }
    catch {
        throw "Falha no healthcheck da API em '$healthUrl'. Detalhe: $($_.Exception.Message)"
    }
}

function Resolve-DeviceSerial {
    param(
        [Parameter(Mandatory = $true)][string]$Adb,
        [string]$PreferredSerial
    )

    if ($PreferredSerial) {
        & $Adb connect $PreferredSerial | Out-Null
        $devicesOutput = & $Adb devices
        if ($devicesOutput -match [regex]::Escape($PreferredSerial)) {
            return $PreferredSerial
        }
        throw "Dispositivo '$PreferredSerial' não está disponível via adb."
    }

    $devices = & $Adb devices
    $deviceLine = ($devices -split "`n" | Select-Object -Skip 1 | Where-Object { $_ -match "\sdevice$" } | Select-Object -First 1)
    if (-not $deviceLine) {
        throw "Nenhum dispositivo adb conectado. Informe -AdbSerial ou conecte o aparelho."
    }

    return ($deviceLine -split "\s+")[0]
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$automationRoot = (Resolve-Path "$scriptRoot\..").Path

$adb = Get-AdbPath
$serial = Resolve-DeviceSerial -Adb $adb -PreferredSerial $AdbSerial

if (-not $NoApiHealthcheck) {
    Assert-ApiHealthy -BaseUrl $ApiUrl
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Android E2E Runner" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "API_URL     : $ApiUrl" -ForegroundColor Gray
Write-Host "ADB_SERIAL  : $serial" -ForegroundColor Gray
Write-Host "APP_PACKAGE : $AppPackage" -ForegroundColor Gray

$env:API_URL = $ApiUrl
$env:ADB_SERIAL = $serial
$env:ANDROID_APP_PACKAGE = $AppPackage
$env:PATH = "$env:LOCALAPPDATA\Android\Sdk\platform-tools;$env:PATH"

Push-Location $automationRoot
try {
    $args = @(
        "-ExecutionPolicy", "Bypass",
        "-File", ".\scripts\run-e2e.ps1"
    )

    if ($SkipBuild) { $args += "-SkipBuild" }
    if ($SkipInstall) { $args += "-SkipInstall" }

    & powershell @args
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
