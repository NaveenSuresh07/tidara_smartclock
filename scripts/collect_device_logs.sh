#!/usr/bin/env bash
# ==============================================================================
# Tidara Smartclock — Android Device Diagnostics & Evidence Collector
# ==============================================================================
# Usage:
#   bash scripts/collect_device_logs.sh [optional_target_dir]
#
# Requirements:
#   - adb installed and present in PATH
#   - Physical Android device connected with USB debugging authorized
# ==============================================================================

set -euo pipefail

PACKAGE_NAME="com.tidara.tidara_smartclock"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUT_DIR="${1:-docs/device_verification_logs/${TIMESTAMP}}"

echo "=================================================================="
echo "  TIDARA SMARTCLOCK — PHYSICAL DEVICE EVIDENCE COLLECTION"
echo "=================================================================="

# 1. Verify ADB presence
if ! command -v adb &> /dev/null; then
    echo "[-] Error: 'adb' was not found in your PATH."
    echo "    Please install the Android SDK Platform-Tools and ensure adb is available."
    exit 1
fi

# 2. Check for connected Android device
DEVICES_COUNT=$(adb devices | grep -v "List of devices" | grep "device$" | wc -l | tr -d ' ')
if [ "$DEVICES_COUNT" -eq 0 ]; then
    echo "[-] Error: No authorized Android device detected via ADB."
    echo "    Connect a physical device via USB with Developer Options & USB Debugging enabled."
    adb devices
    exit 1
fi

mkdir -p "$OUT_DIR"
echo "[+] Detected $DEVICES_COUNT active device(s)."
echo "[+] Collecting evidence into: $OUT_DIR"

# 3. Capture Device Specifications
echo "[+] Capturing hardware and OS specifications..."
{
    echo "=== DEVICE METADATA ==="
    echo "Manufacturer:  $(adb shell getprop ro.product.manufacturer 2>/dev/null || echo 'Unknown')"
    echo "Model:         $(adb shell getprop ro.product.model 2>/dev/null || echo 'Unknown')"
    echo "Device Name:   $(adb shell getprop ro.product.device 2>/dev/null || echo 'Unknown')"
    echo "Android OS:    $(adb shell getprop ro.build.version.release 2>/dev/null || echo 'Unknown')"
    echo "API Level:     $(adb shell getprop ro.build.version.sdk 2>/dev/null || echo 'Unknown')"
    echo "Build ID:      $(adb shell getprop ro.build.display.id 2>/dev/null || echo 'Unknown')"
    echo "Security Patch:$(adb shell getprop ro.build.version.security_patch 2>/dev/null || echo 'Unknown')"
    echo "Timestamp:     $(date)"
} > "$OUT_DIR/device_info.txt"

# 4. Check App Installation Status
echo "[+] Inspecting package state for $PACKAGE_NAME..."
adb shell pm list packages | grep "$PACKAGE_NAME" > "$OUT_DIR/package_installed.txt" || true

# 5. Capture AlarmManager Native Dispatch Queue
echo "[+] Dumping AlarmManager dispatch queue..."
adb shell dumpsys alarm | grep -B 2 -A 8 "$PACKAGE_NAME" > "$OUT_DIR/dumpsys_alarm.txt" || true

# 6. Capture Battery Optimization Whitelist Status
echo "[+] Checking Battery Doze & App Standby status..."
{
    echo "=== DOZE WHITELIST ==="
    adb shell dumpsys deviceidle whitelist | grep "$PACKAGE_NAME" || echo "Not in system Doze whitelist"
    echo ""
    echo "=== APP STANDBY BUCKET ==="
    adb shell am get-standby-bucket "$PACKAGE_NAME" 2>/dev/null || echo "Standby bucket query not supported"
} > "$OUT_DIR/battery_optimization_status.txt" || true

# 7. Capture Runtime Permissions
echo "[+] Capturing granted permissions..."
adb shell dumpsys package "$PACKAGE_NAME" | grep -A 25 "runtime permissions:" > "$OUT_DIR/runtime_permissions.txt" || true

# 8. Capture Recent Logcat for Tidara Components
echo "[+] Dumping recent Logcat entries for Tidara receivers..."
adb logcat -d -v time -s \
    TidaraAlarmReceiver:* \
    TidaraBootReceiver:* \
    TidaraBridge:* \
    flutter:* \
    ActivityManager:* > "$OUT_DIR/logcat_tidara.txt" || true

echo "=================================================================="
echo "[+] SUCCESS: All physical device evidence logs saved successfully."
echo "    Files created in: $OUT_DIR/"
echo "      - device_info.txt"
echo "      - package_installed.txt"
echo "      - dumpsys_alarm.txt"
echo "      - battery_optimization_status.txt"
echo "      - runtime_permissions.txt"
echo "      - logcat_tidara.txt"
echo "=================================================================="

