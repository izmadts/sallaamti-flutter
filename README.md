# Sallaamti — Native App

Flutter client for [sallaamti.com](https://sallaamti.com), talking to the Laravel backend's
`/api/v1` endpoints (Sanctum bearer-token auth). See the backend repo's
`app/Http/Controllers/Api/V1/` for the API and `/admin/api-console` for a live endpoint tester.

## Status: Phase 0 (foundations)

What's here: language picker (EN/UR, RTL), register / log in / WhatsApp-or-SMS code sign-in /
Google & Facebook sign-in, a dashboard shell with module tiles, and a working FAQ screen. No
module's real screens (Nikah, Quran, etc.) exist yet — see the project plan for the phase order.

## Running locally

```
flutter pub get
flutter run
```

By default the app talks to production (`https://sallaamti.com/api/v1`). To point at a local
Laravel dev server instead:

```
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

(`10.0.2.2` is the Android emulator's alias for the host machine's `localhost` — use your
machine's LAN IP instead for a physical device, or `http://localhost:8000/api/v1` for iOS
simulator.)

## Google / Facebook sign-in

These need their own **mobile** OAuth credentials — separate, SHA-1-fingerprinted Android/iOS
client IDs from the website's — registered in the Google Cloud Console and Facebook Developer
Console specifically for this app (`com.sallaamti.app`). Until those are set:

- Add the Android/iOS client IDs to the backend's `.env` as `GOOGLE_MOBILE_CLIENT_IDS`
  (comma-separated) — see `config/services.php` on the backend.
- Facebook needs its App ID wired into `android/app/src/main/res/values/strings.xml` and the
  iOS `Info.plist` per the `flutter_facebook_auth` package's setup docs.

Social sign-in will fail with a clear error until this is done — it won't silently misbehave.

## Known local-environment quirks (documented in code comments where they apply)

- `flutter_secure_storage` is pinned below 11.x — that version requires compiling against
  Android SDK 37, which this machine's SDK/AGP combo doesn't yet resolve cleanly.
- `android/build.gradle.kts` forces a consistent JVM target across all plugin subprojects —
  some plugins don't pin their own Java/Kotlin target, which otherwise fails against a JDK 21
  toolchain.
- `kotlin.incremental=false` in `android/gradle.properties` — the project lives on a different
  drive letter than the global Gradle/pub caches, which crashes Kotlin's incremental compiler
  on Windows. Full rebuilds are slower but reliable.

## Architecture

- `lib/core` — API client (`dio` + Sanctum bearer token), router (`go_router`), per-module
  theming, localization.
- `lib/features/<name>` — one folder per module, each with its own `data/` (API calls) and
  `presentation/` (screens). Mirrors the backend's `Api\V1\*` controllers roughly 1:1.
- `lib/shared/widgets` — cross-feature widgets (e.g. the social sign-in buttons).
