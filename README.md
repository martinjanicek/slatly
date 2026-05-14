<div align="center">

# Žaluzky

**Apple Watch controller for Somfy exterior venetian blinds**

Crown rotates slats, vertical drag opens or closes the blind. Talks directly to the Somfy / TaHoma cloud — no iPhone, hub, or extra bridge required at runtime.

<img src="docs/screenshots/watch-list.png" width="200" alt="Blind list"> &nbsp; <img src="docs/screenshots/watch-detail.png" width="200" alt="Tilt + closure detail">

</div>

---

## What it does

Žaluzky drives Somfy ExteriorVenetianBlind devices over the Overkiz cloud API. The watch app shows every blind on your TaHoma box and lets you control both axes of motion independently:

- **Digital Crown → slat tilt** (`setOrientation`, 0–100)
- **Vertical drag on the screen → closure / position** (`setClosure`, 0–100)
- **Both committed together** through a single debounced `setClosureAndOrientation` request, so the motor receives one combined command instead of a flood of tiny updates.

The visualisation in the centre of the screen is a live preview of the blind: slat thickness reflects tilt (thin = open, thick = closed), and the fill height reflects closure. Pick one of seven slat colours per blind to match your house.

## Features

- **Standalone watchOS app** — runs without an iPhone nearby, talks straight to the Somfy Europe endpoint.
- **iCloud-synced sign-in** — log in once on the iPhone companion (where typing is sane), credentials sync to the watch through `kSecAttrSynchronizable` Keychain.
- **Per-blind colour theming** — Modrá / Bílá / Stříbrná / Antracit / Béžová / Hnědá / Zelená, stored per device URL.
- **Reactive state on launch** — initial closure/tilt come from `core:ClosureState` and `core:SlateOrientationState` on the device, so the UI reflects reality even after manual remote use.
- **Typed, retried OAuth** — the `OverkizClient` actor handles the Somfy password grant, caches the access token, refreshes on expiry, and retries `exec/apply` once on a 401.
- **Tested core** — 8 Swift Testing tests cover login flow, payload shape, cached-token reuse, expired-token refresh, 401 retry, bad-credentials surfacing, and `setClosureAndOrientation` parameter order via a `URLProtocol` mock.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                       Apple Watch (watchOS)                     │
│                                                                 │
│   ZaluzkyApp ── NavigationStack                                 │
│       │                                                         │
│       └─ AppState (ObservableObject)                            │
│             │                                                   │
│             ├─ LoginView ─────► CredentialsStore.save()         │
│             │                                                   │
│             └─ BlindListView ─► TiltView                        │
│                  │                  │                           │
│                  │                  ├─ BlindsGraphic            │
│                  │                  ├─ Crown → tilt             │
│                  │                  ├─ Drag  → closure          │
│                  │                  └─ debounced send           │
│                  ▼                  ▼                           │
│              OverkizClient (Swift package)                      │
│                  │                                              │
└──────────────────┼──────────────────────────────────────────────┘
                   │
                   ▼
       accounts.somfy.com  ── OAuth2 password grant
       ha101-1.overkiz.com ── /setup/devices, /exec/apply

       ┌──────────────────────────────────────┐
       │   iCloud Keychain (synchronisable)   │
       └──────────────────────────────────────┘
            ▲
            │
       iPhone companion app (LoginView → SignedInView)
       — exists only to provide a real keyboard for sign-in;
         can be deleted after credentials reach the watch.
```

### Repository layout

```
.
├── App/                          watchOS SwiftUI sources
│   ├── ZaluzkyApp.swift          @main, NavigationStack, scene-phase keychain refresh
│   ├── AppState.swift            ObservableObject, sign-in, Secrets.swift fallback
│   ├── LoginView.swift           on-watch login (Scribble / dictation)
│   ├── BlindListView.swift       device list with per-blind colour swatch
│   ├── TiltView.swift            crown + drag + status indicator, theme button
│   ├── BlindsGraphic.swift       slat renderer that responds to closure + tilt
│   ├── BlindTheme.swift          7-colour palette, UserDefaults persistence
│   ├── ColorPaletteView.swift    bottom-sheet theme picker
│   └── Assets.xcassets           watch app icon (anthracite blinds) + accent
├── iOS/                          iOS companion (login form + instructions)
├── Packages/OverkizKit/          local SwiftPM package
│   ├── Sources/OverkizKit/
│   │   ├── OverkizClient.swift   actor: OAuth, exec/apply, 401 retry
│   │   ├── OverkizDevice.swift   device model with state parsing
│   │   ├── CommandParameter.swift Encodable enum (Int/Double/String/Bool)
│   │   ├── OverkizError.swift    typed error enum
│   │   └── CredentialsStore.swift iCloud Keychain wrapper
│   └── Tests/OverkizKitTests/    URLProtocol-mocked unit tests
├── scripts/make_icon.py          Pillow script that renders AppIcon.png
└── project.yml                   xcodegen spec — iOS host + embedded watch target
```

## Build & run

### Prerequisites

- Xcode 26 (watchOS 26 SDK)
- Homebrew tools: `xcodegen`
- A Somfy Europe (TaHoma) account with at least one ExteriorVenetianBlind paired

### One-time setup

```bash
brew install xcodegen
xcodegen generate
open Zaluzky.xcodeproj
```

In Xcode, set **Signing & Capabilities → Team** for both the `Zaluzky` (iOS) and `ZaluzkyWatch` targets, or bake your team ID into `project.yml`.

For local development you can paste credentials into `App/Secrets.swift` (gitignored):

```swift
enum Secrets {
    static let somfyUsername = "you@example.com"
    static let somfyPassword = "your-password"
    // legacy seed values — Keychain is the source of truth at runtime
}
```

`App/Secrets.swift.example` ships as the template.

### Run on the watch simulator

```bash
xcodebuild -project Zaluzky.xcodeproj -scheme ZaluzkyWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
  -configuration Debug build

xcrun simctl install booted /path/to/ZaluzkyWatch.app
xcrun simctl launch booted com.punkhive.zaluzky.watchkitapp
```

### Deploy to a paired Apple Watch via CLI (no Xcode UI)

```bash
xcodebuild -project Zaluzky.xcodeproj -scheme ZaluzkyWatch \
  -destination 'generic/platform=watchOS' -configuration Debug \
  -allowProvisioningUpdates build

xcrun devicectl device install app \
  --device <your-watch-udid> \
  /path/to/ZaluzkyWatch.app
```

The watch must have Developer Mode enabled, be on the same Wi-Fi as the Mac, and (in practice) the paired iPhone needs Bluetooth temporarily off so the developer tunnel can negotiate directly over Wi-Fi.

### Tests

```bash
cd Packages/OverkizKit
swift test
```

## Standalone watchOS — App Store gotcha

This was supposed to ship as a standalone watchOS app to TestFlight. In practice, Apple's 2025–2026 tooling rejects pure watchOS IPAs at upload time:

```
ERROR: Could not resolve the software platform:
       Unknown platform alias received: watchOS
```

Despite the [official documentation](https://developer.apple.com/documentation/watchos-apps/creating-independent-watchos-apps/) describing the path, the App Store Connect *New App* form no longer offers watchOS as a platform, iTMSTransporter refuses watchOS-only IPAs, and there is [an unresolved Apple Developer Forum thread](https://developer.apple.com/forums/thread/738218) collecting the same complaint.

The workaround used here:

- Build the watch app as the `ZaluzkyWatch` target with `WKApplication = YES`, `WKRunsIndependentlyOfCompanionApp = YES`, `WKCompanionAppBundleIdentifier = com.punkhive.zaluzky`.
- Wrap it in a tiny `Zaluzky` iOS target whose only job is to host the watch app at submission time and provide a real keyboard for first sign-in.
- After install, the user can delete the iOS app from the home screen — the watch app is marked as runs-independently, so it stays put.

## Credits

Built on top of [`pyoverkiz`](https://github.com/iMicknl/python-overkiz-api)'s reverse-engineered understanding of the Overkiz endpoints — the OAuth client ID/secret and the `exec/apply` payload shape are the same constants the Somfy mobile app uses. No Somfy hardware was harmed in the making of this repo.

## License

MIT — see [LICENSE](LICENSE).
