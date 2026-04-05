#!/usr/bin/env bash
# Run Flutter pointed at the Railway backend.
RAILWAY_URL="https://lattice-production-f7cb.up.railway.app/api"

if adb devices 2>/dev/null | grep -q "device$"; then
  echo "Physical device detected — skipping adb reverse (using Railway URL)"
fi

cd "$(dirname "$0")/Frontend/Flutter"
flutter run --dart-define=API_URL="$RAILWAY_URL" "$@"
