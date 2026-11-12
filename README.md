# Carwash Stamp

Ad-free, offline timestamp camera for Android and iOS. Every photo gets:

- a row of stars above a coloured banner,
- the banner itself: title text (e.g. `세차완료`), the current time, and your logo,
- the date underneath,
- a white footer band with the logo on both sides and a thank-you line.

No location, no accounts, no network access. Photos are saved to the system
gallery (album "Carwash Stamp") and to the app's own folder.

## Build

Requirements: Flutter stable, JDK 17, Android SDK 35 (all installed under the
user profile; see `android/gradle.properties` for the JDK path).

```bash
flutter pub get
flutter build apk --release
```

The APK lands in `build/app/outputs/flutter-apk/app-release.apk`. Copy it to the
phone and open it to install (allow "install from unknown sources" once).

iOS needs a Mac with Xcode: open `ios/Runner.xcworkspace`, set your signing
team, then `flutter build ios`.

## Logo

Drop your logo at `assets/logo.png` to bundle it as the default, or pick one
from the gallery inside the app (Settings > Logo). A square PNG with
transparent background looks best.

## Layout

`lib/painters/stamp_painter.dart` draws the stamp for both the live preview and
the saved photo, so what you see on screen is what gets burned in. All sizes
are fractions of the photo width, so the stamp scales with resolution.
