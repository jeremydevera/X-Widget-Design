// ShortcutsCatalog · 502 curated Apple Shortcuts from Shortcutomation.
//
// Data ships in App/Resources/shortcutomation.json and is decoded once at
// startup. Each entry has an iCloud share UUID; the install flow opens
// https://www.icloud.com/shortcuts/<uuid> which Apple's Shortcuts.app handles.
//
// Categories come straight from the source gallery (LifeOS Toolkits, Brain
// Food, Utilities, etc.) — we don't try to remap them into the original
// 4-bucket UTILITY/FUN/PLANNING/MEDIA enum because the source is much richer.

import Foundation

/// A third-party app a shortcut depends on (Data Jar, Toolbox Pro, etc.).
/// `url` is the official site or App Store link from Shortcutomation's page.
struct RequiredApp: Hashable, Codable {
    let name: String
    let url: String

    var openURL: URL? { URL(string: url) }

    /// Custom URL scheme the app registers, when known. Used by
    /// `UIApplication.canOpenURL` to detect whether the user has it installed.
    /// Returns nil for apps we haven't mapped — those are shown as "unknown".
    var detectionScheme: String? {
        Self.knownSchemes[name]
    }

    /// Hardcoded mapping of "name on shortcutomation.com" → URL scheme.
    /// Each scheme MUST also be listed in the app's Info.plist
    /// `LSApplicationQueriesSchemes` array or `canOpenURL` returns false even
    /// when the app is installed.
    static let knownSchemes: [String: String] = [
        "Data Jar":     "data-jar",
        "Toolbox Pro":  "toolbox-pro",
        "Actions":      "actions",
        "Scriptable":   "scriptable",
        "Text Case":    "textcase",
        "Pushcut":      "pushcut",
        "Charty":       "charty",
        "a-Shell":      "ashell",
        "Any Text":     "any-text",
        "Caffeinated":  "caffeinated",
        "ChatGPT":      "chatgpt",
        "Microsoft Edge": "microsoft-edge",
    ]
}

/// One shortcut as decoded from the bundled JSON.
struct ShortcutEntry: Identifiable, Hashable, Codable {
    let id: String           // == slug, stable identifier
    let name: String         // user-facing display name (no leading emoji)
    let category: String     // raw category string (e.g. "LifeOS Toolkits")
    let blurb: String        // one-line description (synthesized if empty)
    let runName: String      // exact name in Shortcuts.app once installed
    let icloudUUID: String   // 32-char hex from iCloud share URL
    let actions: Int?        // action count (when scraper found it)
    let size: String?        // "28 KB" style size string
    let requiredApps: [RequiredApp] // third-party apps needed

    /// iCloud share URL · primary install path.
    var icloudURL: URL {
        URL(string: "https://www.icloud.com/shortcuts/\(icloudUUID)")!
    }

    /// Deep-link to run by name once installed.
    var openURL: URL {
        let encoded = runName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? runName
        return URL(string: "shortcuts://run-shortcut?name=\(encoded)")!
    }
}

/// What the scraper writes — a flatter shape that we map to ShortcutEntry.
private struct RawEntry: Decodable {
    let slug: String
    let name: String
    let category: String
    let actions: Int?
    let size: String?
    let uuid: String
    let requiredApps: [RequiredApp]?
}

enum ShortcutsCatalog {
    /// Lazily loaded once · safe to call from any thread (let-init is atomic).
    static let all: [ShortcutEntry] = loadFromBundle()

    /// Sorted, unique category names (for chip rows).
    static let categories: [String] = {
        let s = Set(all.map { $0.category })
        return s.sorted()
    }()

    private static func loadFromBundle() -> [ShortcutEntry] {
        guard let url = Bundle.main.url(forResource: "shortcutomation", withExtension: "json") else {
            #if DEBUG
            print("⚠️ shortcutomation.json missing from bundle")
            #endif
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let raw = try JSONDecoder().decode([RawEntry].self, from: data)
            return raw.map { r in
                let blurb: String = {
                    if let a = r.actions, let s = r.size { return "\(a) actions · \(s)" }
                    if let s = r.size { return s }
                    if let a = r.actions { return "\(a) actions" }
                    return r.category
                }()
                return ShortcutEntry(
                    id: r.slug,
                    name: r.name,
                    category: normalizeCategory(r.category),
                    blurb: blurb,
                    runName: r.name,
                    icloudUUID: r.uuid,
                    actions: r.actions,
                    size: r.size,
                    requiredApps: r.requiredApps ?? []
                )
            }
        } catch {
            #if DEBUG
            print("⚠️ shortcutomation.json decode error: \(error)")
            #endif
            return []
        }
    }

    /// Collapses every "API - X" / "API OAuth Dancing" source category into a
    /// single "API" bucket so the chip row stays scannable.
    private static func normalizeCategory(_ raw: String) -> String {
        if raw.hasPrefix("API - ") || raw == "API OAuth Dancing" {
            return "API"
        }
        return raw
    }
}
