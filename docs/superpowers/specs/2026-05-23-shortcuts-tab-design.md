# Shortcuts Tab — Design Spec

**Date:** 2026-05-23
**Status:** Draft for review
**Owner:** Islet

## Goal

Let user browse curated Apple Shortcuts from inside Islet and try **3 launch modes** side-by-side to learn which feels best.

## Why

Hua-Ming Huang's repo has 531 free Shortcuts. Useful, but iOS won't let an app silently run another app's shortcut. Three plausible bridges exist (open, install, deep). Pick by trial.

## Modes

| Mode | Action | iOS plumbing |
| :-- | :-- | :-- |
| **A · OPEN** | Tap → launches `Shortcuts.app` and runs by name | `shortcuts://run-shortcut?name=X` |
| **B · INSTALL** | Tap → opens iCloud import sheet → user adds once | `https://www.icloud.com/shortcuts/<uuid>` |
| **C · DEEP** | Subset that App-Intent-back into Islet | App Intents already wired |

Each card shows all three buttons. User picks per shortcut.

## Sample set (8)

Variety covers utility, API, planning, fun, deep-link.

1. **Coin Flip** — fun, no deps (mode A test)
2. **Color Picker** — utility (A)
3. **Plan My Day** — planning, multi-step (A or B)
4. **Spotify · Play Music** — API integration (B)
5. **NASA Random APOD** — fetch + image (B)
6. **Show Day Progress** — visual output (A)
7. **Get Directions** — Apple Maps deeplink (A)
8. **Log to Islet** — App Intent we expose (C)

User can favorite or hide ones.

## UI

New 6th tab `Shortcuts`. Same chrome as `skills`:
- Header `shortcuts · 8 curated · 3 modes to try`
- Filter chips: ALL · UTILITY · API · PLANNING · FUN · DEEP
- Card per shortcut:
  - Name + emoji
  - 1-line description
  - 3 buttons: OPEN · INSTALL · DEEP (DEEP greyed if not eligible)
  - Status pill if INSTALLed (UserDefaults flag)

Sheet on tap = full description + iCloud QR + author credit.

## Data model

```swift
struct ShortcutEntry {
  let id: String           // "coin-flip"
  let name: String         // "Coin Flip"
  let emoji: String
  let category: ShortcutCategory  // utility / api / planning / fun / deep
  let blurb: String
  let icloudURL: URL?      // for mode B
  let runName: String?     // for mode A
  let appIntent: String?   // for mode C
}
```

Catalog hardcoded. ~50 lines Swift. No backend.

## Mode implementations

**A · OPEN**
```swift
let url = URL(string: "shortcuts://run-shortcut?name=\(name.urlEncoded)")!
UIApplication.shared.open(url)
```
If shortcut not installed, Shortcuts.app shows "shortcut not found".

**B · INSTALL**
```swift
UIApplication.shared.open(entry.icloudURL!)
```
Apple Shortcuts handles import. Mark `installed[id] = true` in UserDefaults via universal-link return.

**C · DEEP**
Existing `IsletIntents.swift` already has `LogMoodIntent` etc. Card jumps to `shortcuts://create-shortcut?actionID=...` (or just opens Shortcuts.app gallery for our app).

## Out of scope (this iteration)

- Actually executing arbitrary shortcuts inside Islet (impossible on iOS)
- Syncing user's installed shortcut state across devices (CloudKit later)
- Generating new shortcuts from inside Islet (PDF/plist export, separate spec)

## Open questions

1. iCloud share-link pattern: Hua-Ming's URLs follow `https://shortcutomation.com/<slug>`. Does redirect chain end at `icloud.com/shortcuts/<uuid>`? Need to verify before mode B works.
2. App Intent donation status — confirm IsletIntents shipped with last build.

## Done means

- 6th tab visible
- 8 cards render with real metadata
- All 3 buttons fire iOS URL schemes (or no-op for ineligible DEEP)
- User reports which mode feels best after a week
