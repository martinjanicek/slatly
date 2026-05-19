# Slatly

Swift 6, xcodegen-driven watchOS + iOS app that drives Somfy `ExteriorVenetianBlind` devices over the Overkiz cloud API. Watch is standalone after first sign-in: it talks to Somfy directly over LTE / Wi-Fi without needing the iPhone nearby. Available in EN / CS / DE / FR / ES.

## Requirements

- macOS with Xcode 26
- [`xcodegen`](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- An Apple Developer account (for code signing; free account works for sideloading)
- A Somfy / TaHoma / Cozytouch account with at least one `ExteriorVenetianBlind` device registered on a Connexoon, TaHoma or Cozytouch box

## Build

```sh
xcodegen generate
open Zaluzky.xcodeproj
```

In `project.yml`, set `DEVELOPMENT_TEAM` to your own team identifier (currently `GB4KCN39XD`). Run the `ZaluzkyWatch` scheme for watch-only development on a paired simulator, or the `Zaluzky` scheme to build the iOS host + embedded watch app.

Direct install on real devices via `xcrun devicectl`:

```sh
# iOS host (also auto-syncs the watch app to your paired Apple Watch)
xcodebuild -project Zaluzky.xcodeproj -scheme Zaluzky \
    -destination 'generic/platform=iOS' -configuration Debug build
xcrun devicectl device install app --device <iphone-udid> \
    ~/Library/Developer/Xcode/DerivedData/Zaluzky-*/Build/Products/Debug-iphoneos/Zaluzky.app

# Watch directly (faster than waiting for iPhone-to-watch sync)
xcodebuild -project Zaluzky.xcodeproj -scheme ZaluzkyWatch \
    -destination 'generic/platform=watchOS' -configuration Debug build
xcrun devicectl device install app --device <watch-udid> \
    ~/Library/Developer/Xcode/DerivedData/Zaluzky-*/Build/Products/Debug-watchos/ZaluzkyWatch.app
```

Watch needs the screen awake for the tunnel to stay connected during install.

## Caveat: watchOS-only distribution

Apple's 2025–2026 tooling refuses watchOS-only IPAs at upload (`Unknown platform alias received: watchOS`), so even though the watch app runs fully standalone, App Store / TestFlight distribution still requires the tiny iOS host target as a wrapper. See [this Apple Developer Forum thread](https://developer.apple.com/forums/thread/738218).

## Architecture

```
App/                    watchOS SwiftUI app
iOS/                    iPhone companion (Dashboard / Rooms / Scenes / Settings)
Shared/                 cross-platform code
WidgetExtension/        watchOS launch complication
iOSWidgets/             iOS home-screen widget (deep-link tiles)
Packages/OverkizKit/    SwiftPM library wrapping the Somfy Europe OAuth2 + exec/apply flow
```

Key modules in `Shared/`:

- `OverkizClient` (in OverkizKit) actor wrapping the Overkiz REST API with URLProtocol-mocked Swift Testing suite
- `CredentialsStore` (iCloud Keychain, `kSecAttrSynchronizable`) for Somfy credentials sync between iPhone + Watch
- `BlindScene` model + `SceneStore` (iCloud Keychain backed) + `SceneSync` (WatchConnectivity push for immediate cross-device delivery)
- `SceneRunner` fans out a scene's per-device setpoints in parallel
- `BlindNameStore` (UserDefaults, per-device rename override) + `BlindThemeStore` (per-device slat colour) + `MyPositionStore` (per-device "My" button override)
- `BlindsGraphic` SwiftUI view, `BlindTheme` palette, `ColorPaletteView`

Sync paths:
- **Credentials** → iCloud Keychain (`kSecAttrSynchronizable`), no extra entitlement needed
- **Scenes** → iCloud Keychain mirror + WatchConnectivity `updateApplicationContext` for immediate push between paired iPhone and Watch
- **Per-device overrides** (name, colour, My position) → local UserDefaults only

## Internal naming

The Xcode project, target names (`Zaluzky`, `ZaluzkyWatch`, `ZaluzkyWidgets`, `ZaluzkyiOSWidgets`) and Bundle Identifiers (`com.punkhive.zaluzky*`) keep the original identifiers from when the app was first named "Žaluzky". They are intentionally left untouched: renaming them would invalidate iCloud Keychain entitlements (existing installs would lose their stored Somfy credentials).

## Localization

UI strings live in per-target `Localizable.xcstrings` (Xcode 26 string catalog format). Source language is English; `cs`, `de`, `es`, `fr` translations included. Per-locale `CFBundleDisplayName` overrides are in `InfoPlist.xcstrings` (currently fixed to "Slatly" across all locales).

## Pre-release TODO

Two capabilities live in `Entitlements/*.entitlements` but are commented out of `project.yml` because they require enabling in the Apple Developer portal first:

- **iCloud Key-Value Store** (`com.apple.developer.ubiquity-kvstore-identifier`) as an additional cross-device scene-sync fallback alongside the current Keychain + WatchConnectivity paths
- **App Groups** which would enable a richer iOS widget that runs scenes inline via App Intents

After enabling those in App Store Connect, uncomment the `CODE_SIGN_ENTITLEMENTS` lines in `project.yml` and rerun `xcodegen generate`.
