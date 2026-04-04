#!/usr/bin/env bash
# Set up adb reverse so physical devices can reach the backend via 127.0.0.1.
if adb devices 2>/dev/null | grep -q "device$"; then
  echo "Physical device detected — setting up adb reverse tcp:8000 tcp:8000"
  adb reverse tcp:8000 tcp:8000
else
  echo "No physical device found via adb, skipping reverse tunnel"
fi

cd "$(dirname "$0")/Frontend/Flutter"
flutter run "$@"
