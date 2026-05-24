// Designs · per-design SwiftUI rendering
//
// One switch maps each design id to its short / long pill view.
// View bodies stay tiny so the file scrolls cleanly even at 50+ designs.

import SwiftUI

struct DesignView: View {
    let design: Design
    let context: RenderContext
    let size: IslandSize
    let edit: DesignEdit

    var body: some View {
        Group {
            switch design.id {
            case "framerate":     fps
            case "cpu-thermal":   cpuThermal
            case "battery-watch": batteryWatch
            case "memory-watch":  memoryWatch
            case "storage-free":  storageFree

            case "weather-now":   weatherNow
            case "weather-clock": weatherClock
            case "weather-uv":    weatherUV

            case "heart-rate":    heartRate
            case "steps":         steps
            case "calories":      calories

            case "big-clock":     bigClock
            case "world-clock":   worldClocks

            case "btc-price":     btcPrice
            case "eth-price":     ethPrice
            case "sport-live":    sportLive

            default:              Text(design.name)
            }
        }
        .foregroundStyle(edit.color.swiftUIColor)
        .font(.system(size: size == .long ? 14 : 12, weight: edit.bold ? .bold : .semibold, design: .monospaced))
    }

    // MARK: DEVICE
    @ViewBuilder private var fps: some View {
        HStack(spacing: 4) {
            Text("fps").font(.caption2).foregroundStyle(.secondary)
            Text("\(context.fps)")
        }
    }
    @ViewBuilder private var cpuThermal: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) { Text("cpu").font(.caption2).foregroundStyle(.secondary); Text("\(context.cpu)%") }
            HStack(spacing: 4) { Text("th").font(.caption2).foregroundStyle(.secondary); Text(String(context.thermal.prefix(4))) }
        }
    }
    @ViewBuilder private var batteryWatch: some View {
        HStack(spacing: 4) {
            Text("⚡").font(.caption2).foregroundStyle(.secondary)
            Text(context.batteryRemaining)
        }
    }
    @ViewBuilder private var memoryWatch: some View {
        HStack(spacing: 4) {
            Text("mem").font(.caption2).foregroundStyle(.secondary)
            Text(String(format: "%.1f", context.memUsedGB)) + Text("GB").font(.caption2).foregroundStyle(.secondary)
        }
    }
    @ViewBuilder private var storageFree: some View {
        HStack(spacing: 4) {
            Text("disk").font(.caption2).foregroundStyle(.secondary)
            Text(String(format: "%.0f", context.diskFreeGB)) + Text("GB").font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: WEATHER
    @ViewBuilder private var weatherNow: some View {
        HStack(spacing: 4) {
            Text(context.weatherGlyph)
            Text("\(context.weatherTempC)°")
        }
    }
    @ViewBuilder private var weatherClock: some View {
        HStack(spacing: 8) {
            Text(context.clock)
            HStack(spacing: 4) { Text(context.weatherGlyph); Text("\(context.weatherTempC)°") }
        }
    }
    @ViewBuilder private var weatherUV: some View {
        HStack(spacing: 4) {
            Text("uv").font(.caption2).foregroundStyle(.secondary)
            Text("\(context.uv)")
        }
    }

    // MARK: HEALTH
    @ViewBuilder private var heartRate: some View {
        HStack(spacing: 4) {
            Circle().frame(width: 7, height: 7)
            Text("\(context.heartRate)")
            Text("BPM").font(.caption2).foregroundStyle(.secondary)
        }
    }
    @ViewBuilder private var steps: some View {
        HStack(spacing: 4) {
            Text("steps").font(.caption2).foregroundStyle(.secondary)
            Text(context.steps.formatted(.number))
        }
    }
    @ViewBuilder private var calories: some View {
        HStack(spacing: 4) {
            Text("kcal").font(.caption2).foregroundStyle(.secondary)
            Text("\(context.calories)")
        }
    }

    // MARK: TIME
    @ViewBuilder private var bigClock: some View {
        Text(context.clock).font(.system(size: size == .long ? 26 : 16, weight: .bold, design: .monospaced))
    }
    @ViewBuilder private var worldClocks: some View {
        HStack(spacing: 8) {
            HStack(spacing: 3) { Text("SF").font(.caption2).foregroundStyle(.secondary); Text(context.clock) }
            HStack(spacing: 3) { Text("NY").font(.caption2).foregroundStyle(.secondary); Text(addHours(context.clock, by: 3)) }
        }
    }

    // MARK: CRYPTO
    @ViewBuilder private var btcPrice: some View {
        HStack(spacing: 4) {
            Text("btc").font(.caption2).foregroundStyle(.secondary)
            Text("$\(Int(context.btcPrice).formatted(.number))")
            Text("\(context.btcChange >= 0 ? "▲" : "▼")\(String(format: "%.1f%%", abs(context.btcChange)))")
                .font(.caption2)
                .foregroundStyle(context.btcChange >= 0 ? .primary : .secondary)
        }
    }
    @ViewBuilder private var ethPrice: some View {
        HStack(spacing: 4) {
            Text("eth").font(.caption2).foregroundStyle(.secondary)
            Text("$\(Int(context.ethPrice).formatted(.number))")
            Text("\(context.ethChange >= 0 ? "▲" : "▼")\(String(format: "%.1f%%", abs(context.ethChange)))")
                .font(.caption2)
                .foregroundStyle(context.ethChange >= 0 ? .primary : .secondary)
        }
    }

    // MARK: SPORTS
    @ViewBuilder private var sportLive: some View {
        HStack(spacing: 6) {
            HStack(spacing: 3) { Text(context.liveHome).font(.caption2).foregroundStyle(.secondary); Text("\(context.liveHomeScore)") }
            Text(context.livePeriod).font(.caption2).foregroundStyle(.secondary)
            HStack(spacing: 3) { Text("\(context.liveAwayScore)"); Text(context.liveAway).font(.caption2).foregroundStyle(.secondary) }
        }
    }

    // MARK: helpers
    private func addHours(_ clock: String, by hours: Int) -> String {
        let parts = clock.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return clock }
        let nh = ((h + hours) % 24 + 24) % 24
        return String(format: "%d:%02d", nh, m)
    }
}
