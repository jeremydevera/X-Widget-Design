# X-Widget-Design · Feature Reference

Triggered by `/xfeatur`. Authoritative list of every feature per tab.

---

## Dashboard

- **Health score** — single 0-100 number showing overall device wellness, blended from CPU headroom, free storage, thermal state, battery level, and Low Power Mode. Status reads EXCELLENT, GOOD, FAIR, or NEEDS ATTENTION.
- **Status factors** — quick four-row breakdown showing CPU headroom, Storage free, Thermal state, and Low Power so you see what's driving the score.
- **Alerts** — auto-generated warnings for low storage, thermal pressure, high CPU, low battery, and Low Power Mode. Falls back to "no issues detected" when clean.
- **Today · Uptime** — hours and minutes since the last reboot.
- **Today · Steps** — today's step count with distance in km below.
- **Today · CPU peak** — highest CPU % observed in the last hour.
- **Today · Thermal peak** — worst thermal state hit today (NORMAL, WARMER, HOT, VERY HOT).
- **Today · Network** — current connection type (WIFI, CELLULAR, WIRED, NONE) with the cellular tech as sub-line.
- **Today · Memory** — current app memory footprint in GB.
- **Storage** — used GB and free GB across one bar; honest note that iOS doesn't expose per-category breakdown to third-party apps.
- **Battery** — current state (UNPLUGGED, CHARGING, FULL), level percentage, computed drain rate per hour, and time remaining estimate. Backed by a live level bar.
- **Trends · 7 days** — four sparklines: CPU peak, Memory peak, Storage free, App launch time. Each card carries a tag showing whether the data is RECORDED by the app or pulled from METRICKIT.

## Skills

- **Skill list** — 20 automations across BATTERY, CONNECTIVITY, FOCUS, HEALTH, and PERFORMANCE categories. Each card shows the trigger, the action, and an ENABLED tag if active. Actions are written to match what an App Store iOS app can actually do (notify, suggest, open another app via Shortcuts, log) — no claims of pausing charging, force-quitting, or auto-toggling Focus modes.
- **Filter chips** — ALL plus one per category, with live counts.
- **Disable all** — top-right button kills every active skill at once.
- **Detail screen** — tap a skill to slide into its config: a big enable toggle, live "when ... then ..." rule preview that updates as you tweak, editable trigger settings (percent thresholds, time pickers, segmented choices, free-form text fields), and a Reset button.

## Island (Dynamic Island Studio)

- **Design list** — 47 dynamic island layouts grouped under DEVICE, WEATHER, HEALTH, TIME, CRYPTO, SPORTS. Each row shows a fixed-size live preview chip + name + category and a `›` arrow.
- **Search** — magnifier icon on the chip row reveals a search bar that filters by name or category.
- **Category filter chips** — ALL plus one per group, with counts.
- **Detail screen** — tap a row to slide into the editor: live preview frame, SHORT/LONG size toggle, apply button, accent color swatches (Mono, Green, Orange, Blue, Pink, Yellow), Bold values toggle, and a Reset button. Crypto designs additionally get a refresh-rate selector (1s / 5s / 15s / 1m / 5m).
- **APPLIED tag** — currently active design is marked with a white left bar and an APPLIED badge in the list.

## Performance

### Compute · your app (process-scoped)

- **CPU** — current CPU % busy across cores, rendered as a slim ring chart.
- **Memory** — app memory footprint in GB, ring chart with `used / total GB` in the header.
- **Thermal** — 4-step iOS state (NORMAL, WARMER, HOT, VERY HOT) with a 4-segment progress track.
- **Battery** — current level %, ring chart, with state (UNPLUGGED / CHARGING / FULL) in the header.
- **Disk free** — free GB, ring chart with `free / total GB`.
- **Cores** — active CPU cores out of total, ring chart.

### Display & audio

- **FPS** — current frame rate, target shown in the header (60 or 120).
- **Brightness** — screen brightness %.
- **Volume** — output volume %.

### Sensors · CoreMotion

- **Pressure** — barometric pressure in hPa, with relative altitude meters below.
- **Heading** — compass heading in degrees with a small needle indicator.
- **Accelerometer** — bipolar bars for X / Y / Z axes in G.
- **Gyroscope** — bipolar bars for X / Y / Z axes in rad/s.
- **Steps** — today's pedometer count.
- **Proximity** — sensor state (NEAR / FAR).

### Network

- **Connection** — current network interface (WIFI, CELLULAR, WIRED, NONE).
- **Cellular tech** — radio access type (5G, LTE, 3G, etc.).

### Device info

- **Model** — device model name.
- **Chip** — system-on-chip name (A17 Pro, etc.).
- **iOS version** — installed iOS version.
- **RAM** — total physical memory in GB.
- **Storage** — total storage capacity in GB.
- **CPU cores** — active / total core count.
- **Display** — native resolution.
- **Refresh rate** — display max Hz (60 or 120 ProMotion).
- **Locale** — system locale identifier.
- **Time zone** — current time zone.
- **Low power mode** — ON / OFF.
- **Uptime** — h m s since last reboot, ticking live.

### CPU history

- **Last 60 seconds** — rolling line graph of CPU samples with current % in the header.

### MetricKit · last daily report

- **Cumulative CPU time** — total seconds of CPU your app used in the last 24h.
- **Peak memory** — highest memory footprint hit, in MB.
- **App launch time (95%)** — 95th percentile time to first draw, in ms.
- **Hang time (>250ms)** — total seconds of UI hangs.
- **Cumulative disk writes** — MB written.
- **Cellular bytes sent** — KB uploaded over cellular.

### View toggle

- **CHART / LIST** — switch every Compute card from ring charts to flat key-value rows. Choice persists per session.

## Settings

### Appearance

- **Theme** — Dark, Midnight, or Paper (full light mode).
- **Compact mode** — denser list rows.
- **Show category tags** — toggles those small DEVICE / CRYPTO labels on each row.
- **Reduce motion** — turns off pulses and transitions.

### Units & formats

- **Temperature** — °C or °F.
- **Distance** — KM or MI.
- **Time** — 12H or 24H.
- **Currency** — USD, EUR, GBP, or PHP.
- **First day of week** — MON or SUN.

### Notifications

- **Allow notifications** — master switch.
- **Sounds** — chime when triggered.
- **Haptics** — subtle taps for events.
- **Quiet hours** — silence non-critical alerts.

### Privacy

- **Share usage analytics** — opt-in telemetry.
- **Crash reports** — anonymized diagnostics.
- **Health access** — triggers the HealthKit permission prompt.
- **App permissions** — opens this app's own Settings page (only deeplink iOS reliably allows).

### Data

- **iCloud sync** — sync designs and skills across devices.
- **Backup now** — manual trigger.
- **Export settings** — downloads the full state as a JSON file.
- **Reset applied design** — sets island back to weather-now.
- **Clear all customizations** — wipes per-design edits and favorites.

### About

- **Version** — app build version.
- **Designs** — total count.
- **Storage used** — localStorage footprint in KB.
- **Send feedback** — mailto.
- **Terms & privacy** — view legal page.
