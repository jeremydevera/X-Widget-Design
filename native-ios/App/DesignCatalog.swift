import Foundation

/// All available designs. Order within category determines the display order.
enum DesignCatalog {
    static let all: [Design] = [
        // ─── DEVICE
        .init(id: "fps-counter",   name: "framerate",         category: "DEVICE"),
        .init(id: "cpu-temp",      name: "cpu + temp",        category: "DEVICE"),
        .init(id: "download",      name: "download progress", category: "DEVICE"),
        .init(id: "battery-watch", name: "battery watch",     category: "DEVICE"),

        // ─── MEDIA
        .init(id: "now-playing",   name: "now playing",       category: "MEDIA"),
        .init(id: "recording",     name: "recording",         category: "MEDIA"),
        .init(id: "live-stream",   name: "live stream",       category: "MEDIA"),

        // ─── WEATHER
        .init(id: "weather-now",   name: "weather now",       category: "WEATHER"),
        .init(id: "weather-clock", name: "weather + clock",   category: "WEATHER"),

        // ─── HEALTH
        .init(id: "heart-rate",    name: "heart rate",        category: "HEALTH"),
        .init(id: "steps",         name: "step counter",      category: "HEALTH"),
        .init(id: "workout",       name: "workout timer",     category: "HEALTH"),

        // ─── TIME
        .init(id: "big-clock",     name: "big clock",         category: "TIME"),

        // ─── FUN
        .init(id: "sample-gif",    name: "sample gif",        category: "FUN"),
        .init(id: "minimal-pulse", name: "just a pulse",      category: "FUN"),
    ]

    static func byId(_ id: String) -> Design? {
        all.first { $0.id == id }
    }

    static var categories: [(String, Int)] {
        let counts = Dictionary(grouping: all, by: \.category).mapValues(\.count)
        return DesignCategory.order.compactMap { c in
            guard let n = counts[c] else { return nil }
            return (c, n)
        }
    }

    static func filtered(_ filter: FilterKey) -> [Design] {
        switch filter {
        case .all: return all
        case .category(let c): return all.filter { $0.category == c }
        }
    }
}
