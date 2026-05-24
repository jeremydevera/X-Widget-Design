// AppState · observable, single source of truth for the whole app
//
// Mirrors the JS `state` object: tab, applied design, edits, prefs, skills.
// Views observe via @EnvironmentObject. UserDefaults persists between launches.

import Foundation
import SwiftUI
import Combine

enum Tab: String, CaseIterable, Identifiable {
    case dashboard, skills, island, performance, settings
    var id: String { rawValue }
    var label: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .skills: return "Skills"
        case .island: return "Island"
        case .performance: return "Performance"
        case .settings: return "Settings"
        }
    }
}

enum IslandSize: String, Codable { case short, long }

enum AccentColor: String, CaseIterable, Codable {
    case mono, green, orange, blue, pink, yellow
    var swiftUIColor: Color {
        switch self {
        case .mono:   return .white
        case .green:  return Color(hex: 0x34d399)
        case .orange: return Color(hex: 0xfb923c)
        case .blue:   return Color(hex: 0x60a5fa)
        case .pink:   return Color(hex: 0xf472b6)
        case .yellow: return Color(hex: 0xfacc15)
        }
    }
}

struct DesignEdit: Codable, Hashable {
    var refreshMs: Int = 1000
    var color: AccentColor = .mono
    var bold: Bool = true
}

struct UnitsPrefs: Codable {
    var temperature: String = "C"   // C | F
    var distance: String = "km"     // km | mi
    var timeFmt: String = "24"      // 12 | 24
    var currency: String = "USD"    // USD | EUR | GBP | PHP
    var weekStart: String = "mon"   // mon | sun
}

struct NotificationPrefs: Codable {
    var allow: Bool = true
    var sounds: Bool = false
    var haptics: Bool = true
    var quietHours: Bool = false
}

struct PrivacyPrefs: Codable {
    var analytics: Bool = false
    var crashes: Bool = true
}

struct AppPrefs: Codable {
    var theme: AppTheme = .dark
    var font: AppFont = .system
    var compact: Bool = false
    var showCategoryTags: Bool = true
    var reduceMotion: Bool = false
    var units: UnitsPrefs = .init()
    var notifications: NotificationPrefs = .init()
    var privacy: PrivacyPrefs = .init()
    var icloudSync: Bool = true
}

extension AppTheme: Codable {}

@MainActor
final class AppState: ObservableObject {
    // ─ Tabs
    @Published var tab: Tab = .dashboard

    // ─ Island
    @Published var appliedDesignId: String = "weather-now"
    @Published var size: IslandSize = .short
    @Published var filter: String = "ALL"
    @Published var query: String = ""
    @Published var edits: [String: DesignEdit] = [:]
    @Published var perfView: String = "chart" // "chart" | "list"

    // ─ Skills
    @Published var enabledSkills: [String] = []
    @Published var skillConfigs: [String: [String: AnyCodableValue]] = [:]
    @Published var skillCategory: String = "ALL"
    @Published var skillSection: String = "notifications" // "notifications" | "shortcuts"
    @Published var shortcutCategory: String = "ALL"

    // ─ Settings
    @Published var prefs: AppPrefs = .init()

    // ─ MARK: persistence
    private static let storeKey = "islet.state.v1"
    private var cancellables = Set<AnyCancellable>()

    init() {
        load()
        // Persist on every meaningful change (debounced)
        Publishers.MergeMany(
            $appliedDesignId.map { _ in () }.eraseToAnyPublisher(),
            $size.map { _ in () }.eraseToAnyPublisher(),
            $filter.map { _ in () }.eraseToAnyPublisher(),
            $edits.map { _ in () }.eraseToAnyPublisher(),
            $enabledSkills.map { _ in () }.eraseToAnyPublisher(),
            $skillConfigs.map { _ in () }.eraseToAnyPublisher(),
            $skillCategory.map { _ in () }.eraseToAnyPublisher(),
            $skillSection.map { _ in () }.eraseToAnyPublisher(),
            $shortcutCategory.map { _ in () }.eraseToAnyPublisher(),
            $prefs.map { _ in () }.eraseToAnyPublisher(),
            $perfView.map { _ in () }.eraseToAnyPublisher(),
            $tab.map { _ in () }.eraseToAnyPublisher(),
            $shortcutsTutorialDismissed.map { _ in () }.eraseToAnyPublisher()
        )
        .debounce(for: .milliseconds(150), scheduler: DispatchQueue.main)
        .sink { [weak self] in self?.save() }
        .store(in: &cancellables)
    }

    private func save() {
        let snapshot = StateSnapshot(
            tab: tab.rawValue,
            appliedDesignId: appliedDesignId,
            size: size,
            filter: filter,
            edits: edits,
            enabledSkills: enabledSkills,
            skillConfigs: skillConfigs,
            skillCategory: skillCategory,
            prefs: prefs,
            perfView: perfView,
            shortcutsTutorialDismissed: shortcutsTutorialDismissed,
            skillSection: skillSection,
            shortcutCategory: shortcutCategory
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: Self.storeKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storeKey),
              let s = try? JSONDecoder().decode(StateSnapshot.self, from: data) else { return }
        if let t = Tab(rawValue: s.tab) { tab = t }
        appliedDesignId = s.appliedDesignId
        size = s.size
        filter = s.filter
        edits = s.edits
        enabledSkills = s.enabledSkills
        skillConfigs = s.skillConfigs
        skillCategory = s.skillCategory
        prefs = s.prefs
        perfView = s.perfView
        shortcutsTutorialDismissed = s.shortcutsTutorialDismissed ?? false
        skillSection = s.skillSection ?? "notifications"
        shortcutCategory = s.shortcutCategory ?? "ALL"
    }

    // ─ MARK: edit helpers
    func edit(for id: String) -> DesignEdit { edits[id] ?? .init() }
    func setEdit(_ edit: DesignEdit, for id: String) { edits[id] = edit }
    func resetEdit(for id: String) { edits.removeValue(forKey: id) }

    // ─ MARK: skill helpers
    func isSkillOn(_ id: String) -> Bool { enabledSkills.contains(id) }
    func setSkillEnabled(_ id: String, _ on: Bool) {
        if on, !enabledSkills.contains(id) { enabledSkills.append(id) }
        if !on { enabledSkills.removeAll { $0 == id } }
    }
    func disableAllSkills() { enabledSkills.removeAll() }

    // ─ MARK: shortcut install state (Shortcuts tab · session-scoped)
    @Published var installedShortcuts: [String] = []
    func isShortcutInstalled(_ id: String) -> Bool { installedShortcuts.contains(id) }
    func markShortcutInstalled(_ id: String) {
        if !installedShortcuts.contains(id) { installedShortcuts.append(id) }
    }

    // ─ MARK: shortcuts onboarding (dismiss the "how it works" banner)
    @Published var shortcutsTutorialDismissed: Bool = false
}

// Persisted snapshot — Codable subset of AppState
private struct StateSnapshot: Codable {
    let tab: String
    let appliedDesignId: String
    let size: IslandSize
    let filter: String
    let edits: [String: DesignEdit]
    let enabledSkills: [String]
    let skillConfigs: [String: [String: AnyCodableValue]]
    let skillCategory: String
    let prefs: AppPrefs
    let perfView: String
    var shortcutsTutorialDismissed: Bool? = nil
    var skillSection: String? = nil
    var shortcutCategory: String? = nil
}

// Heterogeneous Codable value (for skill param overrides which can be String / Int / Double)
enum AnyCodableValue: Codable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(Bool.self)   { self = .bool(v); return }
        if let v = try? c.decode(Int.self)    { self = .int(v); return }
        if let v = try? c.decode(Double.self) { self = .double(v); return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "unknown AnyCodableValue")
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .int(let v):    try c.encode(v)
        case .double(let v): try c.encode(v)
        case .bool(let v):   try c.encode(v)
        }
    }
}
