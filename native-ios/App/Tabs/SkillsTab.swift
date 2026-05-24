// SkillsTab · two sub-sections in one tab.
//
//  ┌─ NOTIFICATIONS ─────────────────────────────────────────┐
//  │   In-app automations (battery, health, performance).    │
//  │   Triggers fire while Islet is open.                    │
//  └─────────────────────────────────────────────────────────┘
//  ┌─ SHORTCUTS ─────────────────────────────────────────────┐
//  │   Curated Apple Shortcuts launcher.                     │
//  │   Two-step flow: STEP 1 INSTALL → STEP 2 RUN.           │
//  └─────────────────────────────────────────────────────────┘
//
// The toggle is a segmented control under the header. Each section persists
// its own filter chip selection through AppState.

import SwiftUI
import UIKit

struct SkillsTab: View {
    @Environment(\.palette) var p
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            TabHeader(title: "skills",
                      subtitle: state.skillSection == "notifications"
                        ? "AUTOMATIONS · \(state.enabledSkills.count) ENABLED"
                        : "\(ShortcutsCatalog.all.count) SHORTCUTS · INSTALL → RUN") {
                if state.skillSection == "notifications" {
                    GhostButton(title: "DISABLE ALL") { state.disableAllSkills() }
                }
            }

            sectionToggle

            switch state.skillSection {
            case "shortcuts": SkillsShortcutsSection()
            default:          SkillsNotificationsSection()
            }
        }
    }

    /// Segmented control between NOTIFICATIONS / SHORTCUTS · top of tab body.
    private var sectionToggle: some View {
        HStack(spacing: 0) {
            sectionButton("NOTIFICATIONS", value: "notifications")
            sectionButton("SHORTCUTS",     value: "shortcuts")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private func sectionButton(_ label: String, value: String) -> some View {
        let on = state.skillSection == value
        return Button { state.skillSection = value } label: {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .monospaced)).tracking(1.4)
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .background(on ? p.hi : p.surface)
                .foregroundStyle(on ? p.bg : p.text3)
                .overlay(Rectangle().stroke(p.line2, lineWidth: 1))
        }.buttonStyle(.plain)
    }
}

// MARK: - NOTIFICATIONS section

private struct SkillsNotificationsSection: View {
    @Environment(\.palette) var p
    @EnvironmentObject var state: AppState
    @State private var openSkill: Skill? = nil

    var body: some View {
        VStack(spacing: 0) {
            Text("get notified when battery, health, or performance thresholds are hit. tap a skill to configure.")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(p.text3)
                .padding(.horizontal, 20).padding(.vertical, 14)

            chipRow

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filtered, id: \.id) { s in
                        skillRow(s)
                    }
                    Color.clear.frame(height: 24)
                }
            }
        }
        .sheet(item: $openSkill) { s in
            SkillDetailSheet(skill: s)
                .environmentObject(state)
                .environment(\.palette, p)
        }
    }

    private var filtered: [Skill] {
        if state.skillCategory == "ALL" { return SkillsCatalog.all }
        return SkillsCatalog.all.filter { $0.category.rawValue == state.skillCategory }
    }

    private var chipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip("ALL", value: "ALL")
                ForEach(SkillCategory.allCases) { c in chip(c.rawValue, value: c.rawValue) }
            }
            .padding(.horizontal, 20).padding(.bottom, 12)
        }
        .background(p.bg)
        .overlay(alignment: .bottom) { Rectangle().frame(height: 1).foregroundStyle(p.line) }
    }
    private func chip(_ label: String, value: String) -> some View {
        let on = state.skillCategory == value
        return Button { state.skillCategory = value } label: {
            Text(label)
                .font(.system(size: 11, weight: on ? .bold : .semibold, design: .monospaced))
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(on ? p.hi : p.bg)
                .foregroundStyle(on ? p.bg : p.text2)
                .overlay(Rectangle().stroke(on ? p.hi : p.line2, lineWidth: 1))
        }.buttonStyle(.plain)
    }

    private func skillRow(_ s: Skill) -> some View {
        let on = state.isSkillOn(s.id)
        return Button { openSkill = s } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(s.name).font(.system(size: 13, weight: .semibold))
                        if on {
                            Text("ENABLED").font(.system(size: 8.5, weight: .bold, design: .monospaced)).tracking(1)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(p.hi).foregroundStyle(p.bg)
                        }
                    }
                    if state.prefs.showCategoryTags {
                        Text(s.category.rawValue).font(.system(size: 10, design: .monospaced)).foregroundStyle(p.text3)
                    }
                    HStack(spacing: 4) {
                        Text("WHEN").font(.system(size: 9.5, weight: .bold, design: .monospaced)).tracking(1.2).foregroundStyle(p.text3)
                        Text(s.when).font(.system(size: 11, design: .monospaced)).foregroundStyle(p.text2)
                    }
                    HStack(spacing: 4) {
                        Text("THEN").font(.system(size: 9.5, weight: .bold, design: .monospaced)).tracking(1.2).foregroundStyle(p.hi)
                        Text(s.then).font(.system(size: 11, design: .monospaced)).foregroundStyle(p.text2)
                    }
                }
                Spacer(minLength: 0)
                RowChevron()
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) { Rectangle().frame(height: 1).foregroundStyle(p.line) }
            .padding(.horizontal, 20)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - SHORTCUTS section

private struct SkillsShortcutsSection: View {
    @Environment(\.palette) var p
    @EnvironmentObject var state: AppState
    @State private var openShortcut: ShortcutEntry? = nil
    @State private var toast: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            Text("apple shortcuts you can install with one tap. browse the catalog, install once, then run any time.")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(p.text3)
                .padding(.horizontal, 20).padding(.vertical, 14)

            if !state.shortcutsTutorialDismissed {
                tutorialBanner
            }

            chipRow

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filtered, id: \.id) { s in
                        shortcutRow(s)
                    }
                    Color.clear.frame(height: 24)
                }
            }
        }
        .toast(message: $toast, alignment: .topTrailing, accent: .green)
        .sheet(item: $openShortcut) { s in
            ShortcutDetailSheet(entry: s)
                .environment(\.palette, p)
                .environmentObject(state)
        }
    }

    private var tutorialBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("HOW IT WORKS")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced)).tracking(1.4)
                    .foregroundStyle(p.hi)
                Spacer()
                Button {
                    withAnimation(.easeOut(duration: 0.18)) {
                        state.shortcutsTutorialDismissed = true
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(p.text3)
                        .padding(6)
                }.buttonStyle(.plain)
            }

            HStack(alignment: .top, spacing: 10) {
                stepBadge("1")
                VStack(alignment: .leading, spacing: 2) {
                    Text("INSTALL")
                        .font(.system(size: 11, weight: .bold, design: .monospaced)).tracking(1.2)
                        .foregroundStyle(p.text)
                    Text("Tap any card → STEP 1 INSTALL → tap Add Shortcut in Apple's sheet.")
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(p.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(alignment: .top, spacing: 10) {
                stepBadge("2")
                VStack(alignment: .leading, spacing: 2) {
                    Text("RUN")
                        .font(.system(size: 11, weight: .bold, design: .monospaced)).tracking(1.2)
                        .foregroundStyle(p.text)
                    Text("Come back to Islet → STEP 2 RUN → shortcut fires every time.")
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(p.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text("STEP 2 stays locked until you finish STEP 1.")
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(p.text3)
                .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(p.bg2)
        .overlay(Rectangle().stroke(p.hi, lineWidth: 1))
        .overlay(alignment: .leading) { Rectangle().frame(width: 2).foregroundStyle(p.hi) }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func stepBadge(_ n: String) -> some View {
        Text(n)
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .frame(width: 22, height: 22)
            .background(p.hi)
            .foregroundStyle(p.bg)
    }

    private var filtered: [ShortcutEntry] {
        if state.shortcutCategory == "ALL" { return ShortcutsCatalog.all }
        return ShortcutsCatalog.all.filter { $0.category == state.shortcutCategory }
    }

    private var chipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip("ALL", value: "ALL")
                ForEach(ShortcutsCatalog.categories, id: \.self) { c in
                    chip(c.uppercased(), value: c)
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 12)
        }
        .background(p.bg)
        .overlay(alignment: .bottom) { Rectangle().frame(height: 1).foregroundStyle(p.line) }
    }

    private func chip(_ label: String, value: String) -> some View {
        let on = state.shortcutCategory == value
        return Button { state.shortcutCategory = value } label: {
            Text(label)
                .font(.system(size: 11, weight: on ? .bold : .semibold, design: .monospaced))
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(on ? p.hi : p.bg)
                .foregroundStyle(on ? p.bg : p.text2)
                .overlay(Rectangle().stroke(on ? p.hi : p.line2, lineWidth: 1))
        }.buttonStyle(.plain)
    }

    private func shortcutRow(_ s: ShortcutEntry) -> some View {
        let installed = state.isShortcutInstalled(s.id)
        let needsApps = !s.requiredApps.isEmpty
        return Button { openShortcut = s } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(s.name).font(.system(size: 13, weight: .semibold))
                        if installed {
                            Text("INSTALLED").font(.system(size: 8.5, weight: .bold, design: .monospaced)).tracking(1)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(p.hi).foregroundStyle(p.bg)
                        }
                        if needsApps {
                            Text("NEEDS APP").font(.system(size: 8.5, weight: .bold, design: .monospaced)).tracking(1)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .overlay(Rectangle().stroke(p.text3, lineWidth: 1))
                                .foregroundStyle(p.text3)
                        }
                    }
                    if state.prefs.showCategoryTags {
                        Text(s.category.uppercased()).font(.system(size: 10, design: .monospaced)).foregroundStyle(p.text3)
                    }
                    Text(s.blurb)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(p.text2)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                RowChevron()
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) { Rectangle().frame(height: 1).foregroundStyle(p.line) }
            .padding(.horizontal, 20)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Skill detail sheet (notifications)

struct SkillDetailSheet: View {
    @Environment(\.palette) var p
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var state: AppState
    let skill: Skill
    @State private var toast: String? = nil
    /// Bumped every time the toggle flips · drives the preview re-animation.
    @State private var animationToken: Int = 0
    @State private var bannerVisible: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Label("BACK", systemImage: "chevron.left")
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 11, weight: .bold, design: .monospaced)).tracking(1.4)
                        .foregroundStyle(p.text2)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(skill.name).font(.system(size: 14, weight: .bold))
                    Text(skill.category.rawValue).font(.system(size: 9.5, weight: .semibold, design: .monospaced)).tracking(1.4).foregroundStyle(p.text3)
                }
                Spacer()
            }
            .padding(14)
            .overlay(alignment: .bottom) { Rectangle().frame(height: 1).foregroundStyle(p.line) }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    notificationPreview
                    skillCard
                }
                .padding(20)
            }
        }
        .background(p.bg)
        .foregroundStyle(p.text)
        .toast(message: $toast, alignment: .topTrailing, accent: .green)
        .onAppear { triggerPreview() }
    }

    /// Replays the slide-down + scale-up banner animation. Called on appear
    /// and via the REPLAY button (not on toggle, so the user has time to read).
    private func triggerPreview() {
        bannerVisible = false
        animationToken &+= 1
        // Slightly longer pre-roll so the user has time to look at the empty
        // banner area before it slides in.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) {
                bannerVisible = true
            }
        }
    }

    /// Combined card · enable toggle + WHEN/THEN rule rows in one tile.
    private var skillCard: some View {
        let on = state.isSkillOn(skill.id)
        return VStack(alignment: .leading, spacing: 0) {
            // Enable toggle row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable skill").font(.system(size: 13, weight: .bold))
                    Text(on ? "currently enabled" : "currently disabled")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(p.text3)
                }
                Spacer()
                MonoToggle(isOn: Binding(
                    get: { on },
                    set: { newValue in
                        state.setSkillEnabled(skill.id, newValue)
                        toast = newValue ? "Skill enabled" : "Skill disabled"
                    }
                ))
            }
            .padding(.vertical, 14)
            .overlay(alignment: .bottom) { Rectangle().frame(height: 1).foregroundStyle(p.line) }

            // WHEN row
            HStack(spacing: 0) {
                Text("WHEN")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced)).tracking(1.2)
                    .foregroundStyle(p.text3)
                    .frame(width: 50, alignment: .leading)
                Text(skill.when)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(p.text)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 10)
            .overlay(alignment: .bottom) { Rectangle().frame(height: 1).foregroundStyle(p.line) }

            // THEN row
            HStack(spacing: 0) {
                Text("THEN")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced)).tracking(1.2)
                    .foregroundStyle(p.hi)
                    .frame(width: 50, alignment: .leading)
                Text(skill.then)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(p.text)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 10)
        }
        .padding(.horizontal, 14)
        .background(p.surface)
        .overlay(Rectangle().stroke(p.line2, lineWidth: 1))
    }

    /// iOS-style notification mockup so the user can picture the actual
    /// banner the skill will fire. Re-animates on appear and toggle.
    private var notificationPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("PREVIEW")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced)).tracking(1.4)
                    .foregroundStyle(p.text3)
                Spacer()
                Button { triggerPreview() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise").font(.system(size: 10, weight: .bold))
                        Text("REPLAY")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced)).tracking(1)
                    }
                    .foregroundStyle(p.text2)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .overlay(Rectangle().stroke(p.line2, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            // The mock banner. Slides down + scales up on each trigger.
            HStack(alignment: .top, spacing: 14) {
                RoundedRectangle(cornerRadius: 11)
                    .fill(p.hi)
                    .frame(width: 52, height: 52)
                    .overlay {
                        Text("I")
                            .font(.system(size: 26, weight: .black))
                            .foregroundStyle(p.bg)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("ISLET")
                            .font(.system(size: 12, weight: .bold, design: .monospaced)).tracking(1.2)
                            .foregroundStyle(p.text2)
                        Spacer()
                        Text("now")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(p.text3)
                    }
                    Text(previewTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(p.text)
                    Text(previewBody)
                        .font(.system(size: 14))
                        .foregroundStyle(p.text2)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(p.surface3)
            )
            .opacity(bannerVisible ? 1 : 0)
            .scaleEffect(bannerVisible ? 1 : 0.92, anchor: .top)
            .offset(y: bannerVisible ? 0 : -36)
            .id(animationToken)
            // Reserve enough vertical space so the empty pre-animation slot
            // is visibly the same size as the final banner.
            .frame(minHeight: 92, alignment: .top)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(p.bg2)
        .overlay(Rectangle().stroke(p.line, lineWidth: 1))
        .clipped() // keeps the slide animation inside the card bounds
    }

    /// Sample title shown in the notification preview banner.
    private var previewTitle: String {
        switch skill.id {
        case "b-100":     return "Battery full"
        case "b-low":     return "Battery low"
        case "b-80stop":  return "Charged to 80%"
        case "h-water":   return "Time to hydrate"
        case "h-steps":   return "Daily goal hit"
        case "p-thermal": return "Device running hot"
        case "p-storage": return "Storage low"
        default:          return skill.name.capitalized
        }
    }

    /// Sample body shown in the notification preview banner.
    private var previewBody: String {
        switch skill.id {
        case "b-100":     return "100% · unplug to preserve battery health."
        case "b-low":     return "18% remaining. Consider Low Power Mode."
        case "b-80stop":  return "Unplug now to keep your battery healthier."
        case "h-water":   return "It's been 90 minutes. Drink some water."
        case "h-steps":   return "10,247 steps · keep it up."
        case "p-thermal": return "Thermal state SERIOUS. Close heavy apps."
        case "p-storage": return "4.2 GB free. Time to clean up."
        default:          return skill.then
        }
    }
}


// MARK: - Shortcut detail sheet (two-step flow)

struct ShortcutDetailSheet: View {
    @Environment(\.palette) var p
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var state: AppState
    let entry: ShortcutEntry
    @State private var toast: String? = nil

    private var installed: Bool { state.isShortcutInstalled(entry.id) }

    /// True only when every required app the entry lists is installed
    /// (or has an unknown URL scheme — we can't verify those, so we
    /// optimistically assume present).
    private var requiredAppsReady: Bool {
        entry.requiredApps.allSatisfy { isAppInstalled($0) }
    }

    /// Probes UIApplication.canOpenURL for the app's known scheme. Returns
    /// nil when we don't have a mapping for this app — caller treats nil as
    /// "unknown, assume installed" so RUN isn't blocked by data gaps.
    private func appInstalledStatus(_ app: RequiredApp) -> Bool? {
        guard let scheme = app.detectionScheme,
              let url = URL(string: "\(scheme)://") else { return nil }
        return UIApplication.shared.canOpenURL(url)
    }

    private func isAppInstalled(_ app: RequiredApp) -> Bool {
        appInstalledStatus(app) ?? true   // unknown → assume yes
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Label("BACK", systemImage: "chevron.left")
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 11, weight: .bold, design: .monospaced)).tracking(1.4)
                        .foregroundStyle(p.text2)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name).font(.system(size: 14, weight: .bold))
                    Text(entry.category.uppercased()).font(.system(size: 9.5, weight: .semibold, design: .monospaced)).tracking(1.4).foregroundStyle(p.text3)
                }
                Spacer()
            }
            .padding(14)
            .overlay(alignment: .bottom) { Rectangle().frame(height: 1).foregroundStyle(p.line) }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    descriptionCard
                    if !entry.requiredApps.isEmpty {
                        requiredAppsCard
                    }
                    progressCard

                    stepCard(
                        number: "1",
                        title: "INSTALL",
                        subtitle: installed
                            ? "Already in your library · tap to reinstall."
                            : "Open Apple's import sheet · tap Add Shortcut.",
                        done: installed,
                        locked: false,
                        action: { runInstall() }
                    )

                    stepCard(
                        number: "2",
                        title: "RUN",
                        subtitle: !installed
                            ? "Locked · finish STEP 1 first."
                            : (!requiredAppsReady
                                ? "Locked · install the required apps below first."
                                : "Launch \(entry.runName) in Shortcuts.app."),
                        done: false,
                        locked: !installed || !requiredAppsReady,
                        action: { runOpen() }
                    )

                    creditCard
                }
                .padding(20)
            }
        }
        .background(p.bg)
        .foregroundStyle(p.text)
        .toast(message: $toast, alignment: .topTrailing, accent: .green)
    }

    // ─────────────── cards ───────────────
    private var descriptionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ABOUT")
                .font(.system(size: 9.5, weight: .bold, design: .monospaced)).tracking(1.4)
                .foregroundStyle(p.text3)
            Text(entry.blurb)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(p.text)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(p.surface)
        .overlay(Rectangle().stroke(p.line2, lineWidth: 1))
    }

    /// Lists third-party apps the shortcut needs (Data Jar, Toolbox Pro, etc.).
    /// Each row probes UIApplication.canOpenURL to show INSTALLED / MISSING.
    /// Tapping an installed app opens it; tapping a missing one opens the
    /// official site (usually the App Store link) so the user can install.
    private var requiredAppsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: requiredAppsReady ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(p.hi)
                Text("REQUIRED APPS")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced)).tracking(1.4)
                    .foregroundStyle(p.hi)
                Spacer()
                Text("\(entry.requiredApps.filter { isAppInstalled($0) }.count)/\(entry.requiredApps.count)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(p.text2)
            }
            Text(requiredAppsReady
                 ? "All required apps detected on this device."
                 : "Install the missing apps below before running the shortcut.")
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(p.text3)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(entry.requiredApps, id: \.name) { app in
                    requiredAppRow(app)
                }
            }
            .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(p.bg2)
        .overlay(Rectangle().stroke(p.hi, lineWidth: 1))
        .overlay(alignment: .leading) { Rectangle().frame(width: 2).foregroundStyle(p.hi) }
    }

    /// One row inside the required-apps card. Shows status pill + button to
    /// open the app (when installed) or its install page (when missing).
    private func requiredAppRow(_ app: RequiredApp) -> some View {
        let status = appInstalledStatus(app)        // true / false / nil(unknown)
        let isInstalled = status == true
        let isMissing = status == false
        return Button {
            if isInstalled, let scheme = app.detectionScheme,
               let url = URL(string: "\(scheme)://") {
                UIApplication.shared.open(url)
            } else if let url = app.openURL {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(isInstalled ? p.hi : (isMissing ? p.text3 : p.line3))
                    .frame(width: 4, height: 4)
                Text(app.name)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(p.text)
                statusPill(installed: status)
                Spacer()
                Text(isInstalled ? "OPEN" : (isMissing ? "INSTALL" : "VIEW"))
                    .font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1)
                    .foregroundStyle(p.text2)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(p.text3)
            }
            .padding(.vertical, 8)
            .overlay(alignment: .bottom) {
                Rectangle().frame(height: 1).foregroundStyle(p.line)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func statusPill(installed: Bool?) -> some View {
        switch installed {
        case .some(true):
            Text("INSTALLED")
                .font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(1)
                .padding(.horizontal, 5).padding(.vertical, 1)
                .background(p.hi).foregroundStyle(p.bg)
        case .some(false):
            Text("MISSING")
                .font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(1)
                .padding(.horizontal, 5).padding(.vertical, 1)
                .overlay(Rectangle().stroke(p.text3, lineWidth: 1))
                .foregroundStyle(p.text3)
        case .none:
            Text("UNKNOWN")
                .font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(1)
                .padding(.horizontal, 5).padding(.vertical, 1)
                .overlay(Rectangle().stroke(p.line3, lineWidth: 1))
                .foregroundStyle(p.text4)
        }
    }

    private var progressCard: some View {
        HStack(spacing: 0) {
            progressSegment(label: "INSTALL", filled: installed)
            Rectangle().fill(installed ? p.hi : p.line2).frame(width: 16, height: 1)
            progressSegment(label: "RUN", filled: false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func progressSegment(label: String, filled: Bool) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().stroke(filled ? p.hi : p.line2, lineWidth: 1.5)
                    .frame(width: 16, height: 16)
                if filled {
                    Circle().fill(p.hi).frame(width: 8, height: 8)
                }
            }
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.4)
                .foregroundStyle(filled ? p.hi : p.text3)
        }
    }

    private func stepCard(number: String, title: String, subtitle: String,
                          done: Bool, locked: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Rectangle()
                        .fill(locked ? p.surface3 : (done ? p.hi.opacity(0.85) : p.hi))
                        .frame(width: 38, height: 38)
                    if done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(p.bg)
                    } else {
                        Text(number)
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundStyle(locked ? p.text3 : p.bg)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("STEP \(number)")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced)).tracking(1.4)
                            .foregroundStyle(p.text3)
                        Text(title)
                            .font(.system(size: 13, weight: .bold, design: .monospaced)).tracking(1.2)
                            .foregroundStyle(locked ? p.text3 : p.text)
                    }
                    Text(subtitle)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(p.text3)
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(p.text4)
                } else {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(p.text2)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(p.surface)
            .overlay(Rectangle().stroke(locked ? p.line2 : p.hi.opacity(done ? 0.5 : 1), lineWidth: 1))
            .opacity(locked ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(locked)
    }

    private var creditCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CREDIT")
                .font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1.4)
                .foregroundStyle(p.text3)
            Text("Curated by Hua-Ming Huang · Shortcutomation gallery (MIT).")
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(p.text2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(p.bg2)
        .overlay(Rectangle().stroke(p.line, lineWidth: 1))
    }

    // ─────────────── actions ───────────────
    private func runOpen() {
        UIApplication.shared.open(entry.openURL) { ok in
            DispatchQueue.main.async {
                toast = ok ? "Opening…" : "Shortcuts.app refused"
            }
        }
    }

    private func runInstall() {
        // iCloud share link · Apple's official install flow.
        UIApplication.shared.open(entry.icloudURL) { ok in
            DispatchQueue.main.async {
                if ok {
                    state.markShortcutInstalled(entry.id)
                    toast = "Tap Add Shortcut →"
                } else {
                    toast = "iCloud unavailable"
                }
            }
        }
    }
}
