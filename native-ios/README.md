# Islet · Native iOS Port

Five-tab Swift / SwiftUI app that mirrors the web prototype:

- **Dashboard** — health score, today panel, storage, battery, 7-day trends
- **Skills** — 20 automations across 5 categories (notify / suggest / log only — App-Store-safe)
- **Island** — design list + detail editor + Live Activities on the Dynamic Island
- **Performance** — slim ring charts for CPU/Memory/Battery/Disk/Cores, sensors, MetricKit, full device info
- **Settings** — theme (dark/midnight/paper), units, notifications, privacy, data, about

## Requirements

- macOS 13+ with Xcode 15+
- iPhone 14 Pro or later for Dynamic Island Live Activities (older devices still run the app, just no DI)
- iOS 17+ on the device
- [xcodegen](https://github.com/yonaskolb/XcodeGen) to generate `.xcodeproj` from `project.yml`

## Generate + open

```bash
brew install xcodegen     # one-time
cd native-ios
xcodegen generate
open Islet.xcodeproj
```

Set your Apple Developer Team ID in `project.yml` under `settings.base.DEVELOPMENT_TEAM`, then `xcodegen generate` again.

## Architecture

```
native-ios/
├── project.yml                       # XcodeGen spec
├── App/
│   ├── IsletApp.swift                # @main, builds environment objects
│   ├── RootView.swift                # 5-tab bottom bar + content router
│   ├── AppState.swift                # observable single source of truth + UserDefaults persistence
│   ├── Theme.swift                   # palette tokens (dark/midnight/paper) + EnvironmentKey
│   ├── Models.swift                  # Design / DesignCategory / RenderContext
│   ├── DesignCatalog.swift           # data — list of all designs
│   ├── Designs.swift                 # SwiftUI views for each design id
│   ├── SkillsCatalog.swift           # data — list of all skills
│   ├── Components.swift              # TabHeader, PreviewPill, RingChart, GhostButton, ...
│   ├── LiveActivityManager.swift     # ActivityKit start/update/end wrapper
│   ├── Services/
│   │   └── DeviceMetrics.swift       # @MainActor sampler · Mach + UIDevice + NWPathMonitor + ProcessInfo
│   └── Tabs/
│       ├── DashboardTab.swift
│       ├── SkillsTab.swift           # + SkillDetailSheet
│       ├── IslandTab.swift           # + DesignDetailSheet
│       ├── PerformanceTab.swift
│       └── SettingsTab.swift
├── Shared/
│   └── DesignAttributes.swift        # ActivityKit payload shared with widget
└── Widget/
    ├── DynamicIslandWidget.swift     # Live Activity rendering (compact / minimal / expanded / lock)
    └── Info.plist
```

## What's hooked up vs stubbed

**Real iOS APIs already wired in `DeviceMetrics.swift`:**
- CPU % via `host_processor_info`
- Memory via `mach_task_basic_info`
- Battery via `UIDevice` (with `isBatteryMonitoringEnabled`)
- Thermal via `ProcessInfo.thermalState`
- Disk via `URLResourceValues`
- Cores via `ProcessInfo.activeProcessorCount`
- Network via `NWPathMonitor`
- Cellular tech via `CTTelephonyNetworkInfo`
- Brightness, refresh rate, locale, timezone, uptime, low power
- Hardware lookup table for marketing model name + chip

**Stubbed (placeholder values, plumbing ready):**
- HealthKit (steps / calories / sleep / heart rate) — wire `HKHealthStore.requestAuthorization` in `DeviceMetrics.swift`
- WeatherKit — replace static weather context with `WeatherService.shared.weather(...)`
- CoreMotion (CMPedometer, CMAltimeter, CMMotionManager) — same pattern
- Crypto + Sports — `URLSession` calls to CoinGecko / ESPN public endpoints
- MetricKit — `MXMetricManagerSubscriber` to receive daily payloads

## Adding a design

1. Append to `DesignCatalog.all`
2. Add a `case "your-id":` branch in `Designs.swift` `DesignView.body`
3. (For Dynamic Island rendering) add a branch in `Widget/DynamicIslandWidget.swift` `WidgetContent.body`

## Notes

- Trademark: Apple owns "xcode". The project name is **Islet** for safety. Display name lives in `App/Info.plist`.
- Strict concurrency is set to `minimal` for iOS 17 compatibility; bump to `complete` once you're on iOS 18+.
