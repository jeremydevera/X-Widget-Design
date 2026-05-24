// PerformanceTab · ring charts (slim) + sensor sections + device info

import SwiftUI

struct PerformanceTab: View {
    @Environment(\.palette) var p
    @EnvironmentObject var metrics: DeviceMetrics
    @EnvironmentObject var state: AppState
    @State private var showMemSheet = false

    var body: some View {
        VStack(spacing: 0) {
            TabHeader(title: "live performance", subtitle: "iOS metrics · mach + metrickit")
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SectionTitle(text: "— COMPUTE · YOUR APP", trailing: AnyView(viewToggle))
                    computeGrid
                    SectionTitle(text: "— CPU · LAST 60s")
                    cpuHistoryGraph
                    SectionTitle(text: "— MEMORY · LAST 60s")
                    memHistoryGraph
                    SectionTitle(text: "— DISPLAY & AUDIO")
                    displayGrid
                    SectionTitle(text: "— SENSORS")
                    sensorsBlock
                    SectionTitle(text: "— NETWORK")
                    networkInfo
                    SectionTitle(text: "— DEVICE INFO")
                    deviceInfo
                    Color.clear.frame(height: 24)
                }
                .padding(.horizontal, 20).padding(.top, 16)
            }
        }
        .sheet(isPresented: $showMemSheet) {
            MemoryBreakdownSheet()
                .environmentObject(metrics)
                .environment(\.palette, p)
        }
    }

    private var viewToggle: some View {
        HStack(spacing: 0) {
            toggleBtn("CHART", "chart")
            toggleBtn("LIST", "list")
        }
        .overlay(Rectangle().stroke(p.line2, lineWidth: 1))
    }
    private func toggleBtn(_ label: String, _ value: String) -> some View {
        let on = state.perfView == value
        return Button { state.perfView = value } label: {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1.2)
                .padding(.vertical, 4).padding(.horizontal, 9)
                .background(on ? p.hi : .clear)
                .foregroundStyle(on ? p.bg : p.text3)
        }
        .buttonStyle(.plain)
    }

    private var computeGrid: some View {
        Group {
            if state.perfView == "chart" {
                LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 8) {
                    cpuCoresCard
                    Button { showMemSheet = true } label: {
                        ringCard("MEMORY", "\(String(format: "%.2f", metrics.memUsedGB))/\(String(format: "%.2f", metrics.memTotalGB)) GB",
                                 value: metrics.memUsedGB, max: metrics.memTotalGB == 0 ? 1 : metrics.memTotalGB,
                                 label: "\(Int(metrics.memUsedGB / max(metrics.memTotalGB, 0.001) * 100))%")
                    }
                    .buttonStyle(.plain)
                    thermalCard
                    storageCard
                }
                // Four battery variants — pick the one you like and we'll keep that one.
                Text("BATTERY · 4 VARIANTS")
                    .font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1.6)
                    .foregroundStyle(p.text3)
                    .padding(.top, 18).padding(.bottom, 6)
                LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 8) {
                    batteryV1   // ring · % headline, hours subtitle
                    batteryV2   // ring · hours headline, % subtitle
                    batteryV3   // horizontal level bar with state below
                    batteryV4   // dual-stat (stacked: % big, hours below)
                }
            } else {
                VStack(spacing: 0) {
                    InfoRow(key: "CPU", value: "\(Int(metrics.cpu))% · \(metrics.cores)/\(metrics.coresTotal) cores")
                    InfoRow(key: "Memory", value: "\(String(format: "%.2f", metrics.memUsedGB))/\(String(format: "%.2f", metrics.memTotalGB)) GB")
                    InfoRow(key: "Thermal", value: metrics.thermal.friendly)
                    InfoRow(key: "Battery", value: "\(Int(metrics.battery))% · \(metrics.batteryRemainingLabel)")
                    InfoRow(key: "Storage used", value: "\(String(format: "%.1f", max(0, metrics.diskTotalGB - metrics.diskFreeGB)))/\(String(format: "%.1f", metrics.diskTotalGB)) GB")
                }
                .background(p.surface)
                .overlay(Rectangle().stroke(p.line2, lineWidth: 1))
            }
        }
    }

    /// Combined CPU + cores card. CPU is the live load; subtitle shows the cores
    /// that are powering it (active / total).
    private var cpuCoresCard: some View {
        VStack(spacing: 14) {
            HStack {
                Text("CPU").font(.system(size: 9.5, weight: .bold, design: .monospaced)).tracking(1.4).foregroundStyle(p.text2)
                Spacer()
                Text("\(metrics.cores)/\(metrics.coresTotal) CORES")
                    .font(.system(size: 9, design: .monospaced)).foregroundStyle(p.text4)
            }
            RingChart(value: metrics.cpu, max: 100, label: "\(Int(metrics.cpu))%")
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(p.surface)
        .overlay(Rectangle().stroke(p.line2, lineWidth: 1))
    }

    // ─────────────── 4 battery variants ───────────────

    /// V1 · ring with % as the big centered label, hours-remaining as a subtitle in the header.
    private var batteryV1: some View {
        VStack(spacing: 14) {
            HStack {
                Text("V1 · BATTERY").font(.system(size: 9.5, weight: .bold, design: .monospaced)).tracking(1.4).foregroundStyle(p.text2)
                Spacer()
                Text(metrics.batteryRemainingLabel)
                    .font(.system(size: 9, design: .monospaced)).foregroundStyle(p.text4)
            }
            ZStack {
                Circle().stroke(p.surface3, lineWidth: 4)
                Circle()
                    .trim(from: 0, to: CGFloat(metrics.battery / 100))
                    .stroke(p.hi, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(metrics.battery))%")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(p.text)
            }
            .frame(width: 64, height: 64)
        }
        .padding(14).frame(maxWidth: .infinity)
        .background(p.surface).overlay(Rectangle().stroke(p.line2, lineWidth: 1))
    }

    /// V2 · ring with hours-remaining as the big label, % as a subtitle.
    private var batteryV2: some View {
        VStack(spacing: 14) {
            HStack {
                Text("V2 · BATTERY").font(.system(size: 9.5, weight: .bold, design: .monospaced)).tracking(1.4).foregroundStyle(p.text2)
                Spacer()
                Text("\(Int(metrics.battery))%")
                    .font(.system(size: 9, design: .monospaced)).foregroundStyle(p.text4)
            }
            ZStack {
                Circle().stroke(p.surface3, lineWidth: 4)
                Circle()
                    .trim(from: 0, to: CGFloat(metrics.battery / 100))
                    .stroke(p.hi, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(metrics.batteryRemainingLabel)
                    .font(.system(size: metrics.batteryRemainingLabel.count > 5 ? 11 : 13,
                                  weight: .bold, design: .monospaced))
                    .foregroundStyle(p.text)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 64, height: 64)
        }
        .padding(14).frame(maxWidth: .infinity)
        .background(p.surface).overlay(Rectangle().stroke(p.line2, lineWidth: 1))
    }

    /// V3 · horizontal level bar with % above, state + hours below.
    private var batteryV3: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("V3 · BATTERY").font(.system(size: 9.5, weight: .bold, design: .monospaced)).tracking(1.4).foregroundStyle(p.text2)
                Spacer()
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(metrics.battery))").font(.system(size: 30, weight: .bold))
                Text("%").font(.system(size: 14, weight: .semibold, design: .monospaced)).foregroundStyle(p.text3)
                Spacer()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(p.surface3)
                    Rectangle().fill(metrics.battery < 20 ? Color(hex: 0xff6b6b) : p.hi)
                        .frame(width: CGFloat(metrics.battery / 100) * geo.size.width)
                }
            }
            .frame(height: 8)
            HStack {
                Text(metrics.batteryState.label).font(.system(size: 9, design: .monospaced)).foregroundStyle(p.text3)
                Spacer()
                Text(metrics.batteryRemainingLabel).font(.system(size: 9, design: .monospaced)).foregroundStyle(p.text3)
            }
        }
        .padding(14).frame(maxWidth: .infinity)
        .background(p.surface).overlay(Rectangle().stroke(p.line2, lineWidth: 1))
    }

    /// V4 · dual-stat. Big % top, hours-remaining smaller below, no ring.
    private var batteryV4: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("V4 · BATTERY").font(.system(size: 9.5, weight: .bold, design: .monospaced)).tracking(1.4).foregroundStyle(p.text2)
                Spacer()
                Image(systemName: metrics.batteryState == .charging ? "bolt.fill" : "battery.100")
                    .font(.system(size: 12)).foregroundStyle(p.text3)
            }
            Text("\(Int(metrics.battery))%")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(p.text)
            Text(metrics.batteryRemainingLabel)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(p.text2)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(p.surface).overlay(Rectangle().stroke(p.line2, lineWidth: 1))
    }

    /// Storage used out of total — uses one decimal place and shows the % full.
    private var storageCard: some View {
        let usedGB = max(0, metrics.diskTotalGB - metrics.diskFreeGB)
        let totalGB = max(metrics.diskTotalGB, 0.001)
        let pct = Int(usedGB / totalGB * 100)
        return VStack(spacing: 14) {
            HStack {
                Text("STORAGE USED").font(.system(size: 9.5, weight: .bold, design: .monospaced)).tracking(1.4).foregroundStyle(p.text2)
                Spacer()
                Text("\(String(format: "%.1f", usedGB))/\(String(format: "%.1f", metrics.diskTotalGB)) GB")
                    .font(.system(size: 9, design: .monospaced)).foregroundStyle(p.text4)
            }
            RingChart(value: usedGB, max: totalGB, label: "\(pct)%")
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(p.surface)
        .overlay(Rectangle().stroke(p.line2, lineWidth: 1))
    }

    private func ringCard(_ title: String, _ unit: String, value: Double, max: Double, label: String) -> some View {
        VStack(spacing: 14) {
            HStack {
                Text(title).font(.system(size: 9.5, weight: .bold, design: .monospaced)).tracking(1.4).foregroundStyle(p.text2)
                Spacer()
                Text(unit).font(.system(size: 9, design: .monospaced)).foregroundStyle(p.text4)
            }
            RingChart(value: value, max: max, label: label)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(p.surface)
        .overlay(Rectangle().stroke(p.line2, lineWidth: 1))
    }

    private var thermalCard: some View {
        VStack(spacing: 14) {
            HStack {
                Text("THERMAL").font(.system(size: 9.5, weight: .bold, design: .monospaced)).tracking(1.4).foregroundStyle(p.text2)
                Spacer()
                Text("STATE").font(.system(size: 9, design: .monospaced)).foregroundStyle(p.text4)
            }
            VStack(spacing: 12) {
                Text(metrics.thermal.friendly)
                    .font(.system(size: 14, weight: .bold, design: .monospaced)).tracking(1.6)
                HStack(spacing: 3) {
                    ForEach(0..<4, id: \.self) { i in
                        Rectangle()
                            .fill(i < thermalRank() ? p.hi : p.surface3)
                            .frame(height: 4)
                    }
                }
                .frame(width: 64)
            }
            .frame(height: 64)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(p.surface)
        .overlay(Rectangle().stroke(p.line2, lineWidth: 1))
    }
    private func thermalRank() -> Int {
        switch metrics.thermal {
        case .nominal: return 1; case .fair: return 2
        case .serious: return 3; case .critical: return 4
        @unknown default: return 1
        }
    }

    private var networkInfo: some View {
        VStack(spacing: 0) {
            InfoRow(key: "Connection", value: metrics.network.rawValue.uppercased())
            InfoRow(key: "Cellular tech", value: metrics.cellTech)
        }
        .background(p.surface)
        .overlay(Rectangle().stroke(p.line2, lineWidth: 1))
    }

    private func memRow(_ label: String, value: Double, swatch: Color) -> some View {
        HStack(spacing: 10) {
            Rectangle().fill(swatch).frame(width: 8, height: 8)
            Text(label).font(.system(size: 11, design: .monospaced)).foregroundStyle(p.text2)
            Spacer()
            Text(String(format: "%.2f GB", value))
                .font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(p.text)
        }
        .padding(.vertical, 6)
    }

    private var displayGrid: some View {
        LazyVGrid(columns: [.init(.flexible()), .init(.flexible()), .init(.flexible())], spacing: 8) {
            statCard("FPS", "/\(metrics.refreshHz)", value: "\(Int(metrics.fps))")
            statCard("BRIGHTNESS", "%", value: "\(Int(metrics.brightness))")
            statCard("VOLUME", "%", value: "\(Int(metrics.volume))")
        }
    }

    private func statCard(_ label: String, _ unit: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.system(size: 9.5, weight: .bold, design: .monospaced)).tracking(1.4).foregroundStyle(p.text2)
                Spacer()
                Text(unit).font(.system(size: 9, design: .monospaced)).foregroundStyle(p.text4)
            }
            Text(value).font(.system(size: 22, weight: .bold)).foregroundStyle(p.text)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(p.surface)
        .overlay(Rectangle().stroke(p.line2, lineWidth: 1))
    }

    private var sensorsBlock: some View {
        VStack(spacing: 0) {
            // Pressure / Altitude · CMAltimeter
            sensorCard {
                LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 8) {
                    sensorMini("PRESSURE", "hPa", value: String(format: "%.1f", metrics.pressureHpa),
                               sub: String(format: "%@%.1f m", metrics.altitudeM >= 0 ? "+" : "", metrics.altitudeM))
                    sensorMini("HEADING", "°", value: String(format: "%.0f", metrics.heading),
                               sub: nil, accessory: AnyView(compass))
                }
            }
            // Accelerometer & Gyroscope · CMMotionManager
            sensorCard {
                axisBlock(title: "ACCELEROMETER", unit: "G",
                          x: metrics.accelX, y: metrics.accelY, z: metrics.accelZ, range: 2)
            }
            sensorCard {
                axisBlock(title: "GYROSCOPE", unit: "rad/s",
                          x: metrics.gyroX, y: metrics.gyroY, z: metrics.gyroZ, range: 3)
            }
            // Pedometer & Proximity · CMPedometer / UIDevice
            sensorCard {
                LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 8) {
                    sensorMini("STEPS", "TODAY", value: metrics.steps.formatted(.number),
                               sub: String(format: "%.2f km", metrics.distanceKm))
                    sensorMini("PROXIMITY", "SENSOR", value: metrics.proximityNear ? "NEAR" : "FAR", sub: nil)
                }
            }
        }
    }

    @ViewBuilder
    private func sensorCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(p.surface)
        .overlay(Rectangle().stroke(p.line2, lineWidth: 1))
        .padding(.bottom, 6)
    }

    private func sensorMini(_ label: String, _ unit: String, value: String, sub: String?, accessory: AnyView? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.system(size: 9.5, weight: .bold, design: .monospaced)).tracking(1.4).foregroundStyle(p.text2)
                Spacer()
                Text(unit).font(.system(size: 9, design: .monospaced)).foregroundStyle(p.text4)
            }
            HStack(spacing: 8) {
                Text(value).font(.system(size: 18, weight: .bold)).foregroundStyle(p.text)
                Spacer()
                accessory
            }
            if let sub = sub {
                Text(sub).font(.system(size: 10, design: .monospaced)).foregroundStyle(p.text3)
            }
        }
    }

    /// Three bipolar bars (X/Y/Z) that grow left or right of center based on sign.
    private func axisBlock(title: String, unit: String, x: Double, y: Double, z: Double, range: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.system(size: 9.5, weight: .bold, design: .monospaced)).tracking(1.4).foregroundStyle(p.text2)
                Spacer()
                Text(unit).font(.system(size: 9, design: .monospaced)).foregroundStyle(p.text4)
            }
            axisRow("X", value: x, range: range)
            axisRow("Y", value: y, range: range)
            axisRow("Z", value: z, range: range)
        }
    }

    private func axisRow(_ axis: String, value: Double, range: Double) -> some View {
        let pct = max(-1, min(1, value / range)) // -1 ... +1
        return HStack(spacing: 8) {
            Text(axis).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(p.text2)
                .frame(width: 12, alignment: .leading)
            Text(String(format: "%@%.2f", value >= 0 ? "+" : "", value))
                .font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(p.text)
                .frame(width: 56, alignment: .leading)
                .animation(.linear(duration: 0.05), value: value)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(p.surface3)
                    // center marker
                    Rectangle().fill(p.line3).frame(width: 1).offset(x: geo.size.width / 2)
                    // bipolar fill: anchored on the center, grows left or right
                    let halfWidth = geo.size.width / 2
                    let mag = abs(pct) * halfWidth
                    let xOffset: CGFloat = pct >= 0 ? halfWidth : (halfWidth - mag)
                    Rectangle().fill(p.hi)
                        .frame(width: mag, height: 3)
                        .offset(x: xOffset, y: (geo.size.height - 3) / 2)
                        .animation(.linear(duration: 0.05), value: pct)
                }
            }
            .frame(height: 8)
        }
    }

    /// Tiny compass needle that rotates with the heading.
    private var compass: some View {
        ZStack {
            Circle().stroke(p.line3, lineWidth: 1)
            // tick lines
            Rectangle().fill(p.text4).frame(width: 1, height: 8).offset(y: -16)
            Rectangle().fill(p.text4).frame(width: 1, height: 8).offset(y: 16)
            Rectangle().fill(p.text4).frame(width: 8, height: 1).offset(x: -16)
            Rectangle().fill(p.text4).frame(width: 8, height: 1).offset(x: 16)
            // needle
            Capsule()
                .fill(p.hi)
                .frame(width: 2, height: 22)
                .offset(y: -11)
                .rotationEffect(.degrees(metrics.heading))
                .animation(.easeInOut(duration: 0.25), value: metrics.heading)
            Text("N").font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundStyle(p.hi)
                .offset(y: -22)
        }
        .frame(width: 44, height: 44)
    }

    private var cpuHistoryGraph: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("CPU").font(.system(size: 9.5, weight: .bold, design: .monospaced)).tracking(1.4).foregroundStyle(p.text2)
                Spacer()
                Text("\(Int(metrics.cpu))%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(p.hi)
            }
            Sparkline(values: metrics.cpuHistory)
                .frame(height: 80)
                .foregroundStyle(p.hi)
            HStack {
                Text("60s").font(.system(size: 8.5, design: .monospaced)).foregroundStyle(p.text4)
                Spacer()
                Text("30s").font(.system(size: 8.5, design: .monospaced)).foregroundStyle(p.text4)
                Spacer()
                Text("NOW").font(.system(size: 8.5, design: .monospaced)).foregroundStyle(p.text4)
            }
        }
        .padding(12)
        .background(p.surface)
        .overlay(Rectangle().stroke(p.line2, lineWidth: 1))
    }

    private var memHistoryGraph: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("MEMORY").font(.system(size: 9.5, weight: .bold, design: .monospaced)).tracking(1.4).foregroundStyle(p.text2)
                Spacer()
                Text("\(String(format: "%.2f", metrics.memUsedGB))/\(String(format: "%.2f", metrics.memTotalGB)) GB")
                    .font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(p.hi)
            }
            Sparkline(values: metrics.memHistory)
                .frame(height: 80)
                .foregroundStyle(p.hi)
            HStack {
                Text("60s").font(.system(size: 8.5, design: .monospaced)).foregroundStyle(p.text4)
                Spacer()
                Text("30s").font(.system(size: 8.5, design: .monospaced)).foregroundStyle(p.text4)
                Spacer()
                Text("NOW").font(.system(size: 8.5, design: .monospaced)).foregroundStyle(p.text4)
            }
        }
        .padding(12)
        .background(p.surface)
        .overlay(Rectangle().stroke(p.line2, lineWidth: 1))
    }

    private var deviceInfo: some View {
        VStack(spacing: 0) {
            InfoRow(key: "Model", value: metrics.deviceModel)
            InfoRow(key: "Chip", value: metrics.chip)
            InfoRow(key: "iOS version", value: metrics.iosVersion)
            InfoRow(key: "RAM", value: "\(String(format: "%.1f", metrics.ramGB)) GB")
            InfoRow(key: "Storage", value: "\(Int(metrics.diskTotalGB)) GB")
            InfoRow(key: "CPU cores", value: "\(metrics.cores)/\(metrics.coresTotal)")
            InfoRow(key: "Display", value: metrics.displayRes)
            InfoRow(key: "Refresh rate", value: "\(metrics.refreshHz) Hz")
            InfoRow(key: "Locale", value: metrics.locale)
            InfoRow(key: "Time zone", value: metrics.timeZone)
            InfoRow(key: "Low power mode", value: metrics.lowPower ? "ON" : "OFF")
            let h = Int(metrics.uptime / 3600), m = Int((metrics.uptime.truncatingRemainder(dividingBy: 3600)) / 60)
            InfoRow(key: "Uptime", value: "\(h)h \(m)m")
        }
        .background(p.surface)
        .overlay(Rectangle().stroke(p.line2, lineWidth: 1))
    }
}

// MARK: - Memory breakdown sheet (tap the MEMORY tile to open)

struct MemoryBreakdownSheet: View {
    @Environment(\.palette) var p
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var metrics: DeviceMetrics

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
                    Text("memory breakdown").font(.system(size: 14, weight: .bold))
                    Text("ACTIVE · WIRED · COMPRESSED · FREE")
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced)).tracking(1.4)
                        .foregroundStyle(p.text3)
                }
                Spacer()
            }
            .padding(14)
            .overlay(alignment: .bottom) { Rectangle().frame(height: 1).foregroundStyle(p.line) }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    summary
                    breakdown
                }
                .padding(20)
            }
        }
        .background(p.bg)
        .foregroundStyle(p.text)
    }

    private var summary: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("\(String(format: "%.2f", metrics.memUsedGB))/\(String(format: "%.2f", metrics.memTotalGB)) GB")
                .font(.system(size: 22, weight: .bold))
            Spacer()
            Text("\(Int(metrics.memUsedGB / max(metrics.memTotalGB, 0.001) * 100))% USED")
                .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.4)
                .foregroundStyle(p.hi)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(p.surface)
        .overlay(Rectangle().stroke(p.line2, lineWidth: 1))
    }

    private var breakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Stacked bar
            GeometryReader { geo in
                HStack(spacing: 0) {
                    let total = max(metrics.memTotalGB, 0.001)
                    Rectangle().fill(p.hi)
                        .frame(width: geo.size.width * CGFloat(metrics.memActiveGB / total))
                    Rectangle().fill(p.hi.opacity(0.7))
                        .frame(width: geo.size.width * CGFloat(metrics.memWiredGB / total))
                    Rectangle().fill(p.hi.opacity(0.45))
                        .frame(width: geo.size.width * CGFloat(metrics.memCompressedGB / total))
                    Rectangle().fill(p.surface3)
                }
            }
            .frame(height: 10)

            VStack(spacing: 0) {
                memLegendRow("Active",     value: metrics.memActiveGB,     swatch: p.hi)
                memLegendRow("Wired",      value: metrics.memWiredGB,      swatch: p.hi.opacity(0.7))
                memLegendRow("Compressed", value: metrics.memCompressedGB, swatch: p.hi.opacity(0.45))
                memLegendRow("Free",       value: metrics.memFreeGB,       swatch: p.surface3)
            }
        }
        .padding(14)
        .background(p.surface)
        .overlay(Rectangle().stroke(p.line2, lineWidth: 1))
    }

    private func memLegendRow(_ label: String, value: Double, swatch: Color) -> some View {
        HStack(spacing: 10) {
            Rectangle().fill(swatch).frame(width: 8, height: 8)
            Text(label).font(.system(size: 11, design: .monospaced)).foregroundStyle(p.text2)
            Spacer()
            Text(String(format: "%.2f GB", value))
                .font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(p.text)
        }
        .padding(.vertical, 6)
    }
}
