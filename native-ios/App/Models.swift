// Models · catalog types (Design, Category, Context)
//
// Every Dynamic Island design is a Design value. The view it renders is
// resolved at render time by `Designs.swift` so this file stays pure data.

import Foundation
import SwiftUI

enum DesignCategory: String, CaseIterable, Codable, Identifiable {
    case device   = "DEVICE"
    case weather  = "WEATHER"
    case health   = "HEALTH"
    case time     = "TIME"
    case crypto   = "CRYPTO"
    case sports   = "SPORTS"
    var id: String { rawValue }
    var label: String { rawValue }
}

enum DesignStatus { case live, pending }

struct Design: Identifiable, Hashable {
    let id: String
    let name: String
    let category: DesignCategory
    let status: DesignStatus

    /// Short hint for why a design is pending (shown in the detail screen).
    var pendingReason: String? {
        switch (status, category) {
        case (.pending, .weather): return "Needs WeatherKit entitlement"
        case (.pending, .crypto):  return "Needs network · CoinGecko / Coinbase"
        case (.pending, .sports):  return "Needs network · ESPN scoreboard"
        case (.pending, .health):  return "Needs HealthKit permission"
        case (.pending, _):        return "Pending external data source"
        default: return nil
        }
    }
}

/// Rendering context · live values pumped in from services.
/// Designs.swift reads from this struct to render its preview.
struct RenderContext {
    var cpu: Int = 0
    var fps: Int = 60
    var memUsedGB: Double = 0
    var memTotalGB: Double = 0
    var battery: Int = 0
    var batteryRemaining: String = "—"   // "4h 12m" or "CHARGING"
    var thermal: String = "NORMAL"
    var diskFreeGB: Double = 0

    var weatherTempC: Int = 21
    var weatherGlyph: String = "☀"
    var uv: Int = 6
    var aqi: Int = 42

    var heartRate: Int = 72
    var steps: Int = 8243
    var calories: Int = 412

    var clock: String = "9:41"
    var date: String = "THU 21"

    var btcPrice: Double = 67284
    var btcChange: Double = 2.4
    var ethPrice: Double = 3142
    var ethChange: Double = -0.8

    var liveHome: String = "LAL"
    var liveAway: String = "BOS"
    var liveHomeScore: Int = 87
    var liveAwayScore: Int = 92
    var livePeriod: String = "Q4"
}
