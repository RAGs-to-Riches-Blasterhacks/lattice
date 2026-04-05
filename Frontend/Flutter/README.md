# Lattice - Flutter App

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- Android Studio (for Android builds)
- Xcode (for iOS builds, macOS only)

## Setup

```bash
flutter pub get
```

## Running Locally

```bash
flutter run --dart-define-from-file=dependencies.json
```

`dependencies.json` contains `API_URL` and `FIREBASE_API_KEY` used by the app at runtime.

## Building for Release

### Android

#### 1. Get the keystore

The release keystore (`lattice-release.keystore`) is not checked into git. Get it from another team member and place it at:

```
Frontend/Flutter/android/lattice-release.keystore
```

#### 2. Create `android/key.properties`

This file is also gitignored. Create it at `Frontend/Flutter/android/key.properties` with:

```properties
storePassword=lattice2026
keyPassword=lattice2026
keyAlias=lattice
storeFile=../lattice-release.keystore
```

The `storeFile` path is relative to `android/app/`, so `../lattice-release.keystore` points up to the `android/` directory where the keystore lives.

#### 3. Build

APK (for direct download / sideloading):

```bash
flutter build apk --release --dart-define-from-file=dependencies.json
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

App Bundle (for Google Play Store):

```bash
flutter build appbundle --release --dart-define-from-file=dependencies.json
```

Output: `build/app/outputs/bundle/release/app-release.aab`

### iOS

#### 1. Open in Xcode

```bash
open ios/Runner.xcworkspace
```

#### 2. Set up signing

- In Xcode, select the Runner target
- Go to Signing & Capabilities
- Select the team (Development Team is already set to `7AZ8S568AR`)
- Ensure "Automatically manage signing" is checked

#### 3. Build

```bash
flutter build ipa --release --dart-define-from-file=dependencies.json
```

Output: `build/ios/ipa/lattice.ipa`

Upload to App Store Connect using Transporter or Xcode.

## Generating a New Keystore (if needed)

If you ever need to create a fresh keystore:

```bash
keytool -genkey -v -keystore android/lattice-release.keystore -alias lattice -keyalg RSA -keysize 2048 -validity 10000
```

**Do not replace the existing keystore** if the app has already been published -- Google Play rejects updates signed with a different key.
