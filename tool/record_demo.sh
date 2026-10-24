#!/usr/bin/env bash
# Records the scripted demo (integration_test/demo_test.dart) on a running
# Android emulator. Expects the profile APK built beforehand with
#   flutter build apk --profile --dart-define=ROMFLOW_DEMO=true \
#     --target=integration_test/demo_test.dart
# so the emulator is not starved by Gradle while it records.
# Output: build/demo/RomFlow-demo.mp4 and drive.log.
set -u
out=build/demo
apk=build/app/outputs/flutter-apk/app-profile.apk
mkdir -p "$out"
package=uz.romflow.workshop

adb wait-for-device
adb shell svc power stayon true
adb shell settings put system screen_off_timeout 1800000 || true
# Let the freshly booted system finish its start-up work, then make sure no
# "isn't responding" dialog keeps the window focus (that pauses text input).
sleep 45
adb shell am broadcast -a android.intent.action.CLOSE_SYSTEM_DIALOGS || true
adb shell input keyevent KEYCODE_HOME || true
sleep 5
adb shell dumpsys window | grep -E 'mCurrentFocus|mFocusedApp' || true

rm -f /tmp/stop-recording
flutter drive --profile --use-application-binary="$apk" \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/demo_test.dart \
  -d emulator-5554 > "$out/drive.log" 2>&1 &
drive=$!

# The live "Joyida" camera step needs the camera: grant it once the app
# is installed (and check it took), so no permission dialog covers the
# recording.
(
  for _ in $(seq 1 300); do
    if adb shell pm list packages "$package" | grep -q "$package"; then
      adb shell pm grant "$package" android.permission.CAMERA 2> /dev/null || true
      if adb shell dumpsys package "$package" |
        grep -q 'android.permission.CAMERA: granted=true'; then
        echo "camera permission granted"
        break
      fi
    fi
    sleep 2
  done
) &

for _ in $(seq 1 300); do
  adb shell dumpsys window | grep -q "mCurrentFocus.*$package" && break
  sleep 1
done
adb shell dumpsys window | grep -E 'mCurrentFocus' || true

# screenrecord stops after at most 180 s, so record in segments.
(
  i=0
  while [ ! -f /tmp/stop-recording ]; do
    i=$((i + 1))
    adb shell screenrecord --size 720x1600 --bit-rate 6000000 \
      --time-limit 170 "/sdcard/demo_$(printf %02d $i).mp4"
  done
) &
recorder=$!

wait "$drive"
status=$?
touch /tmp/stop-recording
sleep 3
adb shell pkill -INT screenrecord || true
sleep 4
kill "$recorder" 2> /dev/null || true

for f in $(adb shell ls /sdcard/ | tr -d '\r' | grep '^demo_.*\.mp4$'); do
  adb pull "/sdcard/$f" "$out/"
done
grep -E 'STEP|DEMO|All tests|Some tests|Error' "$out/drive.log" || true
# Where each skipped step failed, for the CI log.
grep -A8 'DEMO STEP FAILED' "$out/drive.log" | grep -E 'FAILED|demo_test.dart' || true

(
  cd "$out" &&
    ls demo_*.mp4 | sed "s/^/file '/; s/$/'/" > list.txt &&
    ffmpeg -y -loglevel error -f concat -safe 0 -i list.txt \
      -vf "scale=540:-2,fps=30" -c:v libx264 -preset veryfast -crf 25 \
      -pix_fmt yuv420p -movflags +faststart RomFlow-demo.mp4
)
ls -la "$out"
exit $status
