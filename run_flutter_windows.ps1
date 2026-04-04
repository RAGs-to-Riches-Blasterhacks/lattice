# Set up adb reverse so physical devices can reach the backend via 127.0.0.1.
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"

$devices = & $adb devices 2>$null
if ($devices -match "device$") {
    Write-Host "Physical device detected - setting up adb reverse tcp:8000 tcp:8000"
    & $adb reverse tcp:8000 tcp:8000
} else {
    Write-Host "No physical device found via adb, skipping reverse tunnel"
}

Set-Location "$PSScriptRoot\Frontend\Flutter"
flutter run @args
