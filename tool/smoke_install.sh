#!/usr/bin/env bash
# Installs and opens release APKs on a running emulator, the way a phone
# owner would: the previous release first, then the new one over it (data
# kept), then the new one on a clean device. Saves a screenshot and the
# crash log of each run in build/smoke and fails if the app is not running.
# Usage: tool/smoke_install.sh previous.apk new.apk
# Pass "-" as previous.apk when there is no earlier release to update from.
set -u
old=$1 new=$2 out=build/smoke package=uz.romflow.workshop
mkdir -p "$out"
adb wait-for-device
sleep 40
adb shell am broadcast -a android.intent.action.CLOSE_SYSTEM_DIALOGS > /dev/null || true
adb shell input keyevent KEYCODE_HOME || true
status=0

launch() {
  local name=$1
  adb logcat -c || true
  adb shell monkey -p $package -c android.intent.category.LAUNCHER 1 > /dev/null
  sleep 20
  adb exec-out screencap -p > "$out/$name.png"
  adb logcat -d > "$out/$name-logcat.txt" || true
  if adb shell pidof $package > /dev/null; then
    echo "SMOKE $name: running"
  else
    echo "SMOKE $name: NOT RUNNING"
    status=1
  fi
  grep -E "FATAL EXCEPTION|AndroidRuntime|E/flutter" "$out/$name-logcat.txt" | head -40 || true
  adb shell am force-stop $package || true
}

if [ "$old" != "-" ]; then
  echo "== install previous release"
  adb install "$old" || status=1
  launch 1-previous
  echo "== update to the new release over it"
  adb install -r "$new" || { echo "SMOKE update: INSTALL FAILED"; status=1; }
  adb shell dumpsys package $package | grep -E "versionName|versionCode" | head -2
  launch 2-updated
fi
echo "== clean install of the new release"
adb uninstall $package > /dev/null || true
adb install "$new" || { echo "SMOKE clean: INSTALL FAILED"; status=1; }
launch 3-clean
exit $status
