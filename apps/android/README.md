# StaticRe Android Application

Modern native Android application for **my.static.re** built with **Kotlin, Jetpack Compose, Material 3, and Ktor**.

## Features

- **Direct System Share Target:** Share photos, screenshots, videos, documents, or text snippets from any Android app directly into StaticRe -> automatically uploads to Cloudflare R2 and copies the public URL to your clipboard.
- **Upload Screen:** Browse files or paste image/text from clipboard with live progress indicator and instant link copy actions.
- **Asset Library:** Search and browse uploaded files with Coil image thumbnails, one-tap copy (Raw URL, Markdown, HTML), and remote deletion.
- **Settings & Diagnostics:** Configure your `API_KEY`, manage custom endpoints, and perform live connection/latency tests.

## Building and Running

### Option 1: Open in Android Studio
1. Open Android Studio.
2. Select **Open** and choose `apps/android`.
3. Click **Run** (`Shift + F10`) to deploy to your Android device or emulator.

### Option 2: Build with Gradle
```bash
cd apps/android
./gradlew assembleDebug
```
The compiled APK will be located at:
`app/build/outputs/apk/debug/app-debug.apk`

Install directly to a connected device:
```bash
adb install -r app/build/outputs/apk/debug/app-debug.apk
```
