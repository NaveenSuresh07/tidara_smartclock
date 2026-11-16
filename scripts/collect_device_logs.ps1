<#
.SYNOPSIS
    Tidara Smartclock — Android Device Diagnostics & Evidence Collector (PowerShell)

.DESCRIPTION
    Automates the extraction of Android device metadata, AlarmManager queues,
    battery optimization whitelisting, and logcat output for physical hardware verification.

.EXAMPLE
    .\scripts\collect_device_logs.ps1
    .\scripts\collect_device_logs.ps1 -OutputDir "device_logs\Pixel7_Run1"
#>

[CmdletBinding()]
param(
    [string]$OutputDir
)

$ErrorActionPreference = 'Continue'
$PackageName = "com.tidara.tidara_smartclock"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = "docs\device_verification_logs\$Timestamp"
}

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  TIDARA SMARTCLOCK — PHYSICAL DEVICE EVIDENCE COLLECTION (PS)" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# 1. Verify ADB in PATH
$adbCmd = Get-Command adb -ErrorAction SilentlyContinue
if (-not $adbCmd) {
    Write-Host "[-] Error: 'adb' executable not found in PATH." -ForegroundColor Red
    Write-Host "    Install Android SDK Platform-Tools and add adb.exe to your environment PATH."
    exit 1
}

# 2. Check for connected Android device
$devicesRaw = adb devices
$connected = ($devicesRaw | Where-Object { $_ -match "\tdevice$" }).Count

if ($connected -eq 0) {
    Write-Host "[-] Error: No authorized Android device detected via ADB." -ForegroundColor Red
    Write-Host "    Connect a physical device via USB with Developer Options & USB Debugging authorized."
    $devicesRaw | Write-Host
    exit 1
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
Write-Host "[+] Detected $connected active Android device(s)." -ForegroundColor Green
Write-Host "[+] Collecting evidence into: $OutputDir" -ForegroundColor Green

# 3. Capture Device Specifications
Write-Host "[+] Capturing device specifications..."
$deviceInfo = @(
    "=== DEVICE METADATA ==="
    "Manufacturer:   $((adb shell getprop ro.product.manufacturer).Trim())"
    "Model:          $((adb shell getprop ro.product.model).Trim())"
    "Device Name:    $((adb shell getprop ro.product.device).Trim())"
    "Android OS:     $((adb shell getprop ro.build.version.release).Trim())"
    "API Level:      $((adb shell getprop ro.build.version.sdk).Trim())"
    "Build ID:       $((adb shell getprop ro.build.display.id).Trim())"
    "Security Patch: $((adb shell getprop ro.build.version.security_patch).Trim())"
    "Timestamp:      $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')"
)
$deviceInfo | Out-File -FilePath "$OutputDir\device_info.txt" -Encoding utf8

# 4. Check App Installation Status
Write-Host "[+] Checking package installation..."
adb shell pm list packages | Select-String $PackageName | Out-File -FilePath "$OutputDir\package_installed.txt" -Encoding utf8

# 5. Capture AlarmManager Native Dispatch Queue
Write-Host "[+] Capturing AlarmManager dispatch queue..."
adb shell dumpsys alarm | Select-String -Pattern $PackageName -Context 2, 8 | Out-File -FilePath "$OutputDir\dumpsys_alarm.txt" -Encoding utf8

# 6. Capture Battery Optimization & Standby Bucket Status
Write-Host "[+] Checking battery optimization status..."
$batteryInfo = @(
    "=== DOZE WHITELIST ==="
    (adb shell dumpsys deviceidle whitelist | Select-String -Pattern $PackageName)
    ""
    "=== APP STANDBY BUCKET ==="
    (adb shell am get-standby-bucket $PackageName 2>$null)
)
$batteryInfo | Out-File -FilePath "$OutputDir\battery_optimization_status.txt" -Encoding utf8

# 7. Capture Runtime Permissions
Write-Host "[+] Checking runtime permissions..."
adb shell dumpsys package $PackageName | Select-String -Pattern "runtime permissions:" -Context 0, 25 | Out-File -FilePath "$OutputDir\runtime_permissions.txt" -Encoding utf8

# 8. Capture Logcat
Write-Host "[+] Dumping Logcat logs for Tidara components..."
adb logcat -d -v time -s TidaraAlarmReceiver:* TidaraBootReceiver:* TidaraBridge:* flutter:* ActivityManager:* | Out-File -FilePath "$OutputDir\logcat_tidara.txt" -Encoding utf8

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "[+] SUCCESS: Physical device diagnostics captured." -ForegroundColor Green
Write-Host "    Logs stored in: $OutputDir" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Cyan

