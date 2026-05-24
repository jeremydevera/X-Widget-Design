// DesignCatalog · the data side of the design list
//
// Each entry is tagged .live (we have a real iOS data source) or .pending
// (needs WeatherKit / HealthKit / network plumbing the app doesn't ship yet).

import Foundation

enum DesignCatalog {
    static let all: [Design] = [
        // ─ DEVICE · all live (Mach + UIDevice + URLResourceValues)
        Design(id: "framerate",     name: "framerate",      category: .device,  status: .live),
        Design(id: "cpu-thermal",   name: "cpu + thermal",  category: .device,  status: .live),
        Design(id: "battery-watch", name: "battery watch",  category: .device,  status: .live),
        Design(id: "memory-watch",  name: "memory usage",   category: .device,  status: .live),
        Design(id: "storage-free",  name: "storage free",   category: .device,  status: .live),

        // ─ WEATHER · pending (WeatherKit + entitlement)
        Design(id: "weather-now",   name: "weather now",     category: .weather, status: .pending),
        Design(id: "weather-clock", name: "weather + clock", category: .weather, status: .pending),
        Design(id: "weather-uv",    name: "uv index",        category: .weather, status: .pending),

        // ─ HEALTH · steps live (CMPedometer · no HealthKit needed), rest pending
        Design(id: "heart-rate",    name: "heart rate",      category: .health,  status: .pending),
        Design(id: "steps",         name: "step counter",    category: .health,  status: .live),
        Design(id: "calories",      name: "active calories", category: .health,  status: .pending),

        // ─ TIME · all live (Foundation Date + TimeZone)
        Design(id: "big-clock",     name: "big clock",       category: .time,    status: .live),
        Design(id: "world-clock",   name: "world clocks",    category: .time,    status: .live),

        // ─ CRYPTO · pending (public price APIs over URLSession)
        Design(id: "btc-price",     name: "bitcoin price",   category: .crypto,  status: .pending),
        Design(id: "eth-price",     name: "ethereum price",  category: .crypto,  status: .pending),

        // ─ SPORTS · pending (ESPN public scoreboard over URLSession)
        Design(id: "sport-live",    name: "live game",       category: .sports,  status: .pending)
    ]

    static func byId(_ id: String) -> Design? {
        all.first { $0.id == id }
    }
}
