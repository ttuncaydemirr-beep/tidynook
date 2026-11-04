# Tidy Nook (Android)

Relaxing organizing puzzle game. Version 1.0.0, package `com.tidynook.game`, target Android 16 (API 36), min Android 8.0 (API 26).

The whole game is `app/src/main/assets/index.html` (plus the embedded font). `MainActivity` shows it in a WebView
from the app's own assets; the app has no permissions and never goes online.

## Build in GitHub (no install needed)
1. Upload this folder to a private GitHub repository (include the hidden `.github` folder).
2. Settings > Secrets and variables > Actions: add `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`.
3. Actions > Build release > Run workflow. Download `tidy-nook-release` (contains the `.aab` for Play and an `.apk` for testing).

## Build in Android Studio
Open this folder, put `upload-keystore.jks` and `keystore.properties` (from the signing package) in this folder,
then Build > Generate Signed App Bundle, or run `./gradlew bundleRelease`.

## Releasing an update
Raise `versionCode` (and `versionName`) in `app/build.gradle`, replace `app/src/main/assets/index.html`, build again.
Font: Baloo Bhaijaan 2, SIL Open Font License (`app/src/main/assets/fonts/OFL.txt`).
