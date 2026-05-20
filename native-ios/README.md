# Islet · Dynamic Island Designs

Native iOS port of the HTML prototype. Browse → preview → apply real Live Activities to the iPhone's Dynamic Island.

## Requirements

- macOS 13+ with Xcode 15+
- iPhone 14 Pro or later (Dynamic Island only exists on Pro)
- iOS 17+ on the device
- [xcodegen](https://github.com/yonaskolb/XcodeGen) to generate the `.xcodeproj` from `project.yml`

## Generate the Xcode project

```bash
brew install xcodegen      # one-time
cd native-ios
xcodegen generate
open Islet.xcodeproj
```

## Run

1. Pick the `Islet` scheme
2. Select an iPhone 14 Pro+ simulator or your physical device
3. ⌘R

The simulator can show Live Activities in the Dynamic Island (long-press the camera bump area in the simulator menu to reveal it).

## Architecture

```
native-ios/
├── project.yml                  # xcodegen config — edit to rename
├── App/                         # main app target
│   ├── IsletApp.swift           # @main + ContentView root
│   ├── Models.swift             # Design / Category / mock context
│   ├── DesignCatalog.swift      # design catalog (data)
│   ├── Designs.swift            # SwiftUI views for each design
│   ├── Views.swift              # PreviewFrame, DesignRow, FilterChips
│   ├── LiveActivityManager.swift# ActivityKit lifecycle
│   ├── Info.plist
│   └── Islet.entitlements
├── Shared/
│   └── DesignAttributes.swift   # ActivityAttributes shared with widget
└── Widget/                      # widget extension target (Live Activity)
    ├── DynamicIslandWidget.swift
    └── Info.plist
```

## Adding a new design

1. Add an entry in `DesignCatalog.swift`
2. Add a SwiftUI view in `Designs.swift`
3. Wire it into the widget switch in `DynamicIslandWidget.swift`

Pattern is identical for every design — copy/paste an existing one.

## Renaming away from "xcode"

`xcode` is Apple's IDE trademark. The project name is `Islet` for App Store safety.
The display brand in the UI shows "xcode" per the original brief — change it in `App/Views.swift` (`brandName`).
For App Store submission, rename `bundleIdPrefix` in `project.yml` and the display name in `App/Info.plist`.
