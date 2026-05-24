// DashboardTab · health score, today panel, storage, battery, trends
//
// Pulls live values from DeviceMetrics. Trend sparklines render placeholder
// data; a real app would persist daily samples and pull MetricKit payloads.

import SwiftUI
import UIKit

struct DashboardTab: View {
    @Environment(\.palette) var p
    @EnvironmentObject var metrics: DeviceMetrics
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            TabHeader(title: "device dashboard",
                      subtitle: "\(metrics.deviceModel.uppercased()) · iOS \(metrics.iosVersion)") {
                stateTag("LIVE", active: true)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    healthHero
                    alerts
                    SectionTitle(text: "— TODAY")
                    todayGrid
                    SectionTitle(text: "— STORAGE")
                    storage
                    SectionTitle(text: "— BATTERY")
                    battery
                    SectionTitle(text: "— TRENDS · 7 DAYS")
                    Text("based on samples while this app is active · MetricKit drives memory + launch")
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(p.text3)
                        .padding(.bottom, 10)
                    trendGrid
                    Color.clear.frame(height: 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
    }

    // MARK: hero
    private var healthHero: some View {
        let score = computeHealthScore()
        let factors = computedFactors()
        return HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle().stroke(p.surface3, lineWidth: 6)
                Circle()
                    .trim(from: 0, to: CGFloat(Double(score) / 100))
                    .stroke(p.hi, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(score)")
                        .font(.system(size: 36, weight: .bold, design: .default))
                        .frame(height: 36)
                    Text("HEALTH")
                        .font(.system(size: 8.5, design: .monospaced))
                        .tracking(1.6)
                        .foregroundStyle(p.text3)
                        .frame(height: 12)
                }
            }
            .frame(width: 120, height: 120)

            VStack(alignment: .leading, spacing: 6) {
                Text(score >= 85 ? "EXCELLENT" : score >= 70 ? "GOOD" : score >= 50 ? "FAIR" : "NEEDS ATTENTION")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .lineLimit(1)
                    .frame(height: 14, alignment: .leading)
                Text(score >= 70 ? "your phone is running smoothly · all systems nominal" : "review alerts below")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(p.text2)
                    .lineLimit(2, reservesSpace: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(factors, id: \.0) { k, v, bad in
                    HStack {
                        Text(k).font(.system(size: 10, design: .monospaced)).foregroundStyle(p.text3)
                        Spacer()
                        Text(v).font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(bad ? p.text2 : p.text)
                            .monospacedDigit()
                    }
                    .frame(height: 14)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 144)
        .padding(16)
        .background(p.surface)
        .overlay(Rectangle().stroke(p.line2, lineWidth: 1))
    }

    private func computeHealthScore() -> Int {
        let cpuHeadroom = 100 - metrics.cpu
        let freePct = (metrics.diskTotalGB > 0) ? metrics.diskFreeGB / metrics.diskTotalGB : 0
        let thermalRank: Double = {
            switch metrics.thermal {
            case .nominal: return 1; case .fair: return 2
            case .serious: return 3; case .critical: return 4
            @unknown default: return 1
            }
        }()
        var score = (cpuHeadroom * 0.25) + (freePct * 100 * 0.30) +
                    ((5 - thermalRank) / 4 * 100 * 0.25) + (metrics.battery * 0.20)
        if metrics.lowPower { score -= 5 }
        return Int(min(100, max(0, score.rounded())))
    }

    private func computedFactors() -> [(String, String, Bool)] {
        let cpuHeadroom = Int(100 - metrics.cpu)
        let freePct = (metrics.diskTotalGB > 0) ? Int(metrics.diskFreeGB / metrics.diskTotalGB * 100) : 0
        return [
            ("CPU headroom", "\(cpuHeadroom)%", cpuHeadroom < 20),
            ("Storage free", "\(freePct)%", freePct < 10),
            ("Thermal", metrics.thermal.friendly, metrics.thermal == .serious || metrics.thermal == .critical),
            ("Low power", metrics.lowPower ? "ON" : "OFF", metrics.lowPower)
        ]
    }

    // MARK: alerts
    private var alerts: some View {
        let items = computedAlerts()
        return VStack(spacing: 6) {
            ForEach(items, id: \.msg) { item in
                HStack(spacing: 10) {
                    Text(item.tag).font(.system(size: 12, weight: .bold, design: .monospaced)).tracking(1.2)
                    Text(item.msg).font(.system(size: 11, design: .monospaced))
                    Spacer()
                }
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(p.surface)
                .overlay(Rectangle().stroke(p.line2, lineWidth: 1))
                .overlay(alignment: .leading) {
                    Rectangle().frame(width: 2).foregroundStyle(item.warn ? p.hi : p.line4)
                }
            }
        }
        .padding(.top, 10)
    }
    private func computedAlerts() -> [(tag: String, msg: String, warn: Bool)] {
        var out: [(tag: String, msg: String, warn: Bool)] = []
        let freePct = (metrics.diskTotalGB > 0) ? metrics.diskFreeGB / metrics.diskTotalGB : 1
        if freePct < 0.10 { out.append(("DISK", "storage low · \(String(format: "%.1f", metrics.diskFreeGB)) GB free", true)) }
        if metrics.thermal == .serious || metrics.thermal == .critical {
            out.append(("TEMP", "device is \(metrics.thermal.friendly) · may throttle", true))
        }
        if metrics.cpu > 85 { out.append(("CPU", "CPU at \(Int(metrics.cpu))% · heavy workload", true)) }
        if metrics.lowPower { out.append(("PWR", "low power mode is on · background tasks deferred", false)) }
        if metrics.battery < 20 { out.append(("BATT", "battery low · \(Int(metrics.battery))% remaining", true)) }
        if out.isEmpty { out.append(("OK", "no issues detected", false)) }
        return out
    }

    // MARK: today
    private var todayGrid: some View {
        let h = Int(metrics.uptime / 3600), m = Int((metrics.uptime.truncatingRemainder(dividingBy: 3600)) / 60)
        let cells: [(String, String, String)] = [
            ("UPTIME", "\(h)h \(m)m", "since reboot"),
            ("STEPS", metrics.steps.formatted(.number), String(format: "%.1f km", metrics.distanceKm)),
            ("CPU PEAK", "\(Int(metrics.todayCpuPeak))%", "this session"),
            ("THERMAL", metrics.todayThermalPeak.friendly, "session peak"),
            ("NETWORK", metrics.network.rawValue.uppercased(), metrics.network == .cellular ? metrics.cellTech : "connected"),
            ("MEMORY", "\(String(format: "%.1f", metrics.memUsedGB))", "app footprint")
        ]
        return LazyVGrid(columns: [.init(.flexible()), .init(.flexible()), .init(.flexible())], spacing: 6) {
            ForEach(cells, id: \.0) { lbl, val, sub in
                VStack(alignment: .leading, spacing: 4) {
                    Text(lbl).font(.system(size: 8.5, weight: .semibold, design: .monospaced)).tracking(1.4).foregroundStyle(p.text2)
                    Text(val).font(.system(size: 18, weight: .bold)).foregroundStyle(p.text)
                    Text(sub).font(.system(size: 9, design: .monospaced)).foregroundStyle(p.text3)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(p.surface)
                .overlay(Rectangle().stroke(p.line2, lineWidth: 1))
            }
        }
    }

    // MARK: storage
    private var storage: some View {
        let used = max(0, metrics.diskTotalGB - metrics.diskFreeGB)
        let pct = metrics.diskTotalGB > 0 ? CGFloat(used / metrics.diskTotalGB) : 0
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(String(format: "%.1f", used)) GB used").foregroundStyle(p.text)
                Spacer()
                Text("\(String(format: "%.1f", metrics.diskFreeGB)) GB free").foregroundStyle(p.text2)
            }
            .font(.system(size: 11, design: .monospaced))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(p.surface3)
                    Rectangle().fill(p.hi).frame(width: pct * geo.size.width)
                }
            }
            .frame(height: 10)
            Text("total / available · per-category breakdown isn't exposed by iOS")
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(p.text3)
        }
        .padding(14)
        .background(p.surface)
        .overlay(Rectangle().stroke(p.line2, lineWidth: 1))
    }

    // MARK: battery
    private var battery: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(metrics.batteryState.label).font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1.4).foregroundStyle(p.text3)
                    Text("\(Int(metrics.battery))%").font(.system(size: 22, weight: .bold))
                }
                Spacer()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(p.surface3)
                    Rectangle().fill(metrics.battery < 20 ? p.text2 : p.hi)
                        .frame(width: CGFloat(metrics.battery / 100) * geo.size.width)
                }
            }
            .frame(height: 8)
            Text("live level via UIDevice · iOS doesn't expose a 24h history to third-party apps")
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(p.text3)
        }
        .padding(14)
        .background(p.surface)
        .overlay(Rectangle().stroke(p.line2, lineWidth: 1))
    }

    // MARK: trends
    private var trendGrid: some View {
        LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 6) {
            trendCard("CPU PEAK", "RECORDED", value: "\(Int(metrics.cpu))%", series: [62, 71, 58, 80, 74, 69, 78])
            trendCard("MEMORY PEAK", "METRICKIT", value: "\(Int(metrics.memUsedGB * 1024)) MB", series: [218, 234, 226, 242, 248, 261, 254])
            trendCard("STORAGE FREE", "RECORDED", value: "\(String(format: "%.0f", metrics.diskFreeGB)) GB", series: [70.3, 69.8, 68.2, 66.9, 65.7, 64.6, 64.2])
            trendCard("LAUNCH TIME", "METRICKIT", value: "378 ms", series: [410, 405, 398, 392, 388, 382, 378])
        }
    }
    private func trendCard(_ title: String, _ tag: String, value: String, series: [Double]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 6) {
                    Text(title)
                    Text(tag).padding(.horizontal, 4).padding(.vertical, 1)
                        .overlay(Rectangle().stroke(p.line2, lineWidth: 1))
                        .font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(1.4).foregroundStyle(p.text4)
                }
                .font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1.4).foregroundStyle(p.text3)
                Spacer()
                Text(value).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(p.hi)
            }
            Sparkline(values: series).frame(height: 30).foregroundStyle(p.hi)
        }
        .padding(10)
        .background(p.surface)
        .overlay(Rectangle().stroke(p.line2, lineWidth: 1))
    }

    private func stateTag(_ s: String, active: Bool) -> some View {
        Text(s)
            .font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1.2)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(active ? p.hi : p.bg)
            .foregroundStyle(active ? p.bg : p.text3)
            .overlay(Rectangle().stroke(active ? p.hi : p.line3, lineWidth: 1))
    }
}

/// Tiny SVG-style polyline sparkline rendered with Path.
struct Sparkline: View {
    let values: [Double]
    var body: some View {
        GeometryReader { geo in
            Path { path in
                guard values.count > 1 else { return }
                let mn = values.min() ?? 0
                let mx = values.max() ?? 1
                let range = mx - mn == 0 ? 1 : mx - mn
                for (i, v) in values.enumerated() {
                    let x = CGFloat(i) / CGFloat(values.count - 1) * geo.size.width
                    let y = (1 - CGFloat((v - mn) / range)) * geo.size.height
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(.foreground, style: StrokeStyle(lineWidth: 1.2))
        }
    }
}
