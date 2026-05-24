// SettingsTab · appearance, units, notifications, privacy, data, about

import SwiftUI
import UIKit

struct SettingsTab: View {
    @Environment(\.palette) var p
    @EnvironmentObject var state: AppState
    @State private var toast: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            TabHeader(title: "settings", subtitle: "preferences · v0.3.0")
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    appearance
                    units
                    notifications
                    privacy
                    data
                    about
                    Color.clear.frame(height: 24)
                }
                .padding(.horizontal, 20).padding(.top, 16)
            }
        }
        .overlay(alignment: .bottom) {
            if let t = toast {
                Text(t)
                    .font(.system(size: 11, weight: .bold, design: .monospaced)).tracking(1)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(p.hi).foregroundStyle(p.bg)
                    .padding(.bottom, 80)
            }
        }
    }

    private var appearance: some View {
        Group {
            SectionTitle(text: "— APPEARANCE")
            seg(title: "Theme", desc: "color scheme",
                value: Binding(get: { state.prefs.theme.rawValue }, set: { state.prefs.theme = AppTheme(rawValue: $0) ?? .dark }),
                options: AppTheme.allCases.map { ($0.rawValue, $0.label) })
            fontPicker
            tog(title: "Compact mode", desc: "denser list rows", value: $state.prefs.compact)
            tog(title: "Show category tags", desc: "DEVICE, WEATHER, etc on each row", value: $state.prefs.showCategoryTags)
            tog(title: "Reduce motion", desc: "turn off pulses and transitions", value: $state.prefs.reduceMotion)
        }
    }

    /// Horizontal scrolling picker for the global app font · 11 options.
    /// Each chip shows the font name rendered in that font, with the active
    /// one highlighted. Doesn't fit in `seg()` because there are too many.
    private var fontPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Text design").font(.system(size: 13, weight: .medium))
                    Text("typeface for the whole app").font(.system(size: 10, design: .monospaced)).foregroundStyle(p.text3)
                }
                Spacer()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(AppFont.allCases) { f in
                        fontChip(f)
                    }
                }
                .padding(.bottom, 2)
            }
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { Rectangle().frame(height: 1).foregroundStyle(p.line) }
    }

    private func fontChip(_ f: AppFont) -> some View {
        let on = state.prefs.font == f
        let isDefault = f == .default
        return Button { state.prefs.font = f } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(f.label)
                        .font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1.2)
                        .foregroundStyle(on ? p.bg : p.text3)
                    if isDefault {
                        Text("DEFAULT")
                            .font(.system(size: 7, weight: .bold, design: .monospaced)).tracking(1)
                            .padding(.horizontal, 3).padding(.vertical, 1)
                            .overlay(Rectangle().stroke(on ? p.bg.opacity(0.5) : p.line2, lineWidth: 1))
                            .foregroundStyle(on ? p.bg : p.text4)
                    }
                }
                Text("Aa")
                    .font(.system(size: 22, design: f.design))
                    .foregroundStyle(on ? p.bg : p.text)
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .frame(minWidth: 70, alignment: .leading)
            .background(on ? p.hi : p.surface)
            .overlay(Rectangle().stroke(on ? p.hi : p.line2, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
    private var units: some View {
        Group {
            SectionTitle(text: "— UNITS & FORMATS")
            seg(title: "Temperature", desc: "weather widgets",
                value: $state.prefs.units.temperature, options: [("C", "°C"), ("F", "°F")])
            seg(title: "Distance", desc: "workouts, distance widgets",
                value: $state.prefs.units.distance, options: [("km", "KM"), ("mi", "MI")])
            seg(title: "Time", desc: "12 or 24 hour clock",
                value: $state.prefs.units.timeFmt, options: [("12", "12H"), ("24", "24H")])
            seg(title: "Currency", desc: "crypto + portfolio widgets",
                value: $state.prefs.units.currency,
                options: [("USD", "USD"), ("EUR", "EUR"), ("GBP", "GBP"), ("PHP", "PHP")])
            seg(title: "First day of week", desc: "weekly views",
                value: $state.prefs.units.weekStart, options: [("mon", "MON"), ("sun", "SUN")])
        }
    }
    private var notifications: some View {
        Group {
            SectionTitle(text: "— NOTIFICATIONS")
            tog(title: "Allow notifications", desc: "required for skills + alerts", value: $state.prefs.notifications.allow)
            tog(title: "Sounds", desc: "play chime when triggered", value: $state.prefs.notifications.sounds)
            tog(title: "Haptics", desc: "subtle taps for events", value: $state.prefs.notifications.haptics)
            tog(title: "Quiet hours", desc: "silence non-critical alerts", value: $state.prefs.notifications.quietHours)
        }
    }
    private var privacy: some View {
        Group {
            SectionTitle(text: "— PRIVACY")
            tog(title: "Share usage analytics", desc: "help improve the app", value: $state.prefs.privacy.analytics)
            tog(title: "Crash reports", desc: "send anonymized diagnostics", value: $state.prefs.privacy.crashes)
            row(title: "Health access", desc: "grants for HealthKit reads") {
                GhostButton(title: "REQUEST") { showToast("triggers HealthKit permission prompt") }
            }
            row(title: "App permissions", desc: "opens this app's settings page") {
                GhostButton(title: "OPEN") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
    }
    private var data: some View {
        Group {
            SectionTitle(text: "— DATA")
            tog(title: "iCloud sync", desc: "sync designs + skills across devices", value: $state.prefs.icloudSync)
            row(title: "Backup now", desc: "last backup 2 days ago") {
                GhostButton(title: "BACKUP") { showToast("backup saved") }
            }
            row(title: "Reset applied design", desc: "go back to weather now") {
                GhostButton(title: "RESET") {
                    state.appliedDesignId = "weather-now"
                    showToast("reset to weather now")
                }
            }
            row(title: "Clear all customizations", desc: "colors and edits") {
                GhostButton(title: "CLEAR") {
                    state.edits.removeAll()
                    showToast("customizations cleared")
                }
            }
        }
    }
    private var about: some View {
        Group {
            SectionTitle(text: "— ABOUT")
            row(title: "Version", desc: "x-widget-design") { Text("0.3.0").font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundStyle(p.text2) }
            row(title: "Designs", desc: "total available") { Text("\(DesignCatalog.all.count)").font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundStyle(p.text2) }
        }
    }

    private func tog(title: String, desc: String, value: Binding<Bool>) -> some View {
        row(title: title, desc: desc) { MonoToggle(isOn: value) }
    }

    private func seg(title: String, desc: String, value: Binding<String>, options: [(String, String)]) -> some View {
        row(title: title, desc: desc) {
            HStack(spacing: 0) {
                ForEach(options, id: \.0) { opt in
                    Button { value.wrappedValue = opt.0 } label: {
                        Text(opt.1)
                            .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1)
                            .padding(.vertical, 7).padding(.horizontal, 10)
                            .background(value.wrappedValue == opt.0 ? p.hi : .clear)
                            .foregroundStyle(value.wrappedValue == opt.0 ? p.bg : p.text3)
                    }.buttonStyle(.plain)
                }
            }
            .overlay(Rectangle().stroke(p.line2, lineWidth: 1))
        }
    }

    private func row<Trailing: View>(title: String, desc: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(desc).font(.system(size: 10, design: .monospaced)).foregroundStyle(p.text3)
            }
            Spacer()
            trailing()
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { Rectangle().frame(height: 1).foregroundStyle(p.line) }
    }

    private func showToast(_ msg: String) {
        toast = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { toast = nil }
    }
}
