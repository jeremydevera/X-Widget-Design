// SkillsCatalog · curated list of useful in-app notifications.
//
// Every skill here fires a real notification from inside Islet via SkillsRunner.
// Triggers are watched on the device — no Shortcuts setup, no entitlements.

import Foundation

enum SkillCategory: String, CaseIterable, Codable, Identifiable {
    case battery     = "BATTERY"
    case health      = "HEALTH"
    case performance = "PERFORMANCE"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .battery:     return "⚡"
        case .health:      return "♥"
        case .performance: return "▣"
        }
    }
}

struct Skill: Identifiable, Hashable {
    let id: String
    let name: String
    let category: SkillCategory
    let when: String
    let then: String
}

enum SkillsCatalog {
    static let all: [Skill] = [
        // BATTERY
        .init(id: "b-100",       name: "full charge alert",      category: .battery,     when: "battery reaches 100%",                  then: "banner + haptic"),
        .init(id: "b-low",       name: "low battery warning",    category: .battery,     when: "battery drops below 20%",               then: "banner suggesting Low Power Mode"),
        .init(id: "b-80stop",    name: "stop charging at 80%",   category: .battery,     when: "battery hits 80% while charging",       then: "banner suggesting unplug"),

        // HEALTH
        .init(id: "h-water",     name: "hydrate",                category: .health,      when: "every 90 min · 9–18",                   then: "subtle banner reminder"),
        .init(id: "h-steps",     name: "daily step goal",        category: .health,      when: "steps cross 10,000 today",              then: "celebration banner with sound"),

        // PERFORMANCE
        .init(id: "p-thermal",   name: "thermal warning",        category: .performance, when: "device is hot or worse",                then: "banner + suggest closing apps"),
        .init(id: "p-storage",   name: "storage cleanup",        category: .performance, when: "free storage falls below 5 GB",         then: "banner with cleanup hint")
    ]
}
