#!/usr/bin/env bash
# Detect local network IP (cross-platform: macOS and Linux/Ubuntu)
if [[ "$(uname)" == "Darwin" ]]; then
  LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)
else
  LOCAL_IP=$(ip route get 1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1); exit}')
fi

if [[ -z "$LOCAL_IP" ]]; then
  echo "Warning: could not detect local IP, falling back to 127.0.0.1"
  LOCAL_IP="127.0.0.1"
fi

API_URL="http://$LOCAL_IP:8000/api"

# For Android: set up adb reverse so the device can reach localhost directly
if adb devices 2>/dev/null | grep -q "device$"; then
  echo "Android device detected — setting up adb reverse tcp:8000 tcp:8000"
  adb reverse tcp:8000 tcp:8000
  API_URL="http://127.0.0.1:8000/api"
else
  echo "No Android device found via adb — using local IP: $API_URL"
fi

cd "$(dirname "$0")/Frontend/Flutter"
flutter run --dart-define=API_URL="$API_URL" "$@"
