# X-Widget · Dynamic Island Designer

Browse, preview, and apply pre-designed Dynamic Island layouts on iPhone 14 Pro and later. Two implementations live here: an HTML prototype for fast design iteration and a native iOS port that uses ActivityKit Live Activities to render in the actual Dynamic Island.

In-app brand: `xcode` (display only). Project name: `Islet` (avoiding Apple's IDE trademark for App Store safety).

## Repository layout

```
.
├── index.html                           HTML prototype · scroll-driven browse → preview → apply
├── app.css                              styles for the prototype
├── app.js                               state, designs catalog, scroll observer
├── deck.html                            original 3-phone reference deck (kept for context)
├── styles.css                           styles for deck.html
└── native-ios/                          Swift / SwiftUI port
    ├── README.md                        build instructions
    ├── project.yml                      xcodegen config
    ├── App/                             main app target
    ├── Shared/                          ActivityAttributes shared with the widget
    └── Widget/                          widget extension (the Live Activity)
```

## HTML prototype

Open `index.html` in any modern browser. No build step.

Designs are organized into 6 categories: DEVICE, MEDIA, WEATHER, HEALTH, TIME, FUN.

- Filter chips at the top of the list narrow to a category, ALL groups under section headers
- Scroll the list and the focused row (closest to the focal line) drives the preview frame plus the actual Dynamic Island simulated at the top of the iPhone frame
- SHORT and LONG show the same content, the LONG version just adds horizontal breathing room
- Apply locks the focused design as the active one (sticky until changed)

Adding a design: drop one entry into the `DESIGNS` array in `app.js` with `id`, `name`, `category`, and `short(ctx)` returning HTML.

## Native iOS port

See [native-ios/README.md](native-ios/README.md) for build and run.

Quick version on macOS with Xcode 15+:

```bash
cd native-ios
brew install xcodegen
xcodegen generate
open Islet.xcodeproj
```

Architecture notes:

- The Dynamic Island is system-managed, so the app starts a Live Activity rather than rendering into the Island directly
- Each design has two representations: an in-app SwiftUI preview and a widget-extension view that Apple renders in the Island's compact, expanded, and minimal regions
- `DesignAttributes.designId` chooses which design to render; the widget switches on it

## Status

Working prototype. Real metric data (CPU, FPS, temp) is mocked. For App Store distribution most live device telemetry is sandboxed and would need to be replaced with HealthKit, WeatherKit, MediaPlayer, or attributes you push from your own app.
