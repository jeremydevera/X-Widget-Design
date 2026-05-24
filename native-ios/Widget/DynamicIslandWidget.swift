// DynamicIslandWidget · Live Activity rendering for the Dynamic Island

import ActivityKit
import SwiftUI
import WidgetKit

@main
struct IsletWidgetBundle: WidgetBundle {
    var body: some Widget {
        IsletLiveActivity()
    }
}

struct IsletLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DesignAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(Color.black)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    WidgetContent(designId: context.attributes.designId,
                                  state: context.state, size: .long)
                }
            } compactLeading: {
                WidgetContent(designId: context.attributes.designId,
                              state: context.state, size: .short, slot: .leading)
            } compactTrailing: {
                WidgetContent(designId: context.attributes.designId,
                              state: context.state, size: .short, slot: .trailing)
            } minimal: {
                MinimalView(designId: context.attributes.designId, state: context.state)
            }
        }
    }
}

enum WidgetSlot { case leading, trailing }
enum WidgetSizeMode { case short, long }

struct WidgetContent: View {
    let designId: String
    let state: DesignAttributes.ContentState
    let size: WidgetSizeMode
    var slot: WidgetSlot? = nil

    var body: some View {
        switch designId {
        case "framerate":     fps
        case "weather-now":   weather
        case "heart-rate":    heart
        case "cpu-thermal":   cpuThermal
        case "big-clock":     bigClock
        case "battery-watch": battery
        case "steps":         steps
        case "memory-watch":  memWatch
        case "storage-free":  storageFree
        case "world-clock":   worldClock
        default:              fallback
        }
    }

    @ViewBuilder private var fps: some View {
        if size == .long {
            HStack(spacing: 6) {
                Text("FPS").font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
                Text("\(state.fps)").font(.system(size: 22, weight: .bold, design: .monospaced)).foregroundStyle(.white)
                Text("/ 120").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
            }
        } else if slot == .leading {
            // In LONG mode the user wants a wider compact pill, so emit more content
            if state.isLong {
                HStack(spacing: 4) {
                    Text("FPS").font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(AnyShapeStyle(.secondary))
                    Text("\(state.fps)").font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(AnyShapeStyle(Color.white))
                }
            } else {
                Text("FPS")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AnyShapeStyle(.secondary))
            }
        } else {
            // trailing slot
            if state.isLong {
                HStack(spacing: 4) {
                    Text("/").font(.system(size: 11, design: .monospaced)).foregroundStyle(AnyShapeStyle(.secondary))
                    Text("120").font(.system(size: 13, weight: .semibold, design: .monospaced)).foregroundStyle(AnyShapeStyle(Color.white))
                    Text("FPS").font(.system(size: 11, design: .monospaced)).foregroundStyle(AnyShapeStyle(.secondary))
                }
            } else {
                Text("\(state.fps)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(AnyShapeStyle(Color.white))
            }
        }
    }

    @ViewBuilder private var weather: some View {
        if size == .long {
            HStack(spacing: 8) {
                Image(systemName: state.weatherGlyph).font(.system(size: 22)).foregroundStyle(.white)
                Text("\(state.weatherTemp)°").font(.system(size: 24, weight: .bold, design: .monospaced)).foregroundStyle(.white)
            }
        } else if slot == .leading {
            Image(systemName: state.weatherGlyph).font(.system(size: 14)).foregroundStyle(.white)
        } else {
            Text("\(state.weatherTemp)°").font(.system(size: 14, weight: .semibold, design: .monospaced)).foregroundStyle(.white)
        }
    }

    @ViewBuilder private var heart: some View {
        if size == .long {
            HStack(spacing: 6) {
                Image(systemName: "heart.fill").foregroundStyle(.white)
                Text("\(state.heartRate)").font(.system(size: 22, weight: .bold, design: .monospaced)).foregroundStyle(.white)
                Text("BPM").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
            }
        } else if slot == .leading {
            Image(systemName: "heart.fill").font(.system(size: 12)).foregroundStyle(.white)
        } else {
            Text("\(state.heartRate)").font(.system(size: 13, weight: .semibold, design: .monospaced)).foregroundStyle(.white)
        }
    }

    @ViewBuilder private var cpuThermal: some View {
        if size == .long {
            HStack(spacing: 14) {
                valueLabel("CPU", "\(state.cpu)%")
                valueLabel("THERMAL", thermalFriendly(state.temp))
                valueLabel("MEM", String(format: "%.1fGB", state.memoryGB))
            }
        } else if slot == .leading {
            if state.isLong {
                HStack(spacing: 4) {
                    Text("CPU").font(.system(size: 11, design: .monospaced)).foregroundStyle(AnyShapeStyle(.secondary))
                    Text("\(state.cpu)%").font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(AnyShapeStyle(Color.white))
                }
            } else {
                Text("\(state.cpu)%").font(.system(size: 13, weight: .semibold, design: .monospaced)).foregroundStyle(.white)
            }
        } else {
            if state.isLong {
                HStack(spacing: 4) {
                    Text("TH").font(.system(size: 11, design: .monospaced)).foregroundStyle(AnyShapeStyle(.secondary))
                    Text(thermalFriendlyShort(state.temp)).font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(AnyShapeStyle(Color.white))
                }
            } else {
                Text(thermalFriendlyShort(state.temp)).font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(.white)
            }
        }
    }

    /// Map the numeric thermal proxy back to the iOS friendly enum label.
    private func thermalFriendly(_ t: Double) -> String {
        switch t {
        case ..<37:  return "NORMAL"
        case ..<40:  return "WARMER"
        case ..<44:  return "HOT"
        default:     return "VERY HOT"
        }
    }
    private func thermalFriendlyShort(_ t: Double) -> String {
        switch t {
        case ..<37:  return "OK"
        case ..<40:  return "WARM"
        case ..<44:  return "HOT"
        default:     return "!!!"
        }
    }

    @ViewBuilder private var bigClock: some View {
        Text(state.clockText)
            .font(.system(size: size == .long ? 32 : 14, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
    }

    @ViewBuilder private var battery: some View {
        if size == .long {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill").foregroundStyle(.white)
                Text(state.batteryRemaining).font(.system(size: 22, weight: .bold, design: .monospaced)).foregroundStyle(.white)
                Text("\(state.battery)%").font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
            }
        } else if slot == .leading {
            if state.isLong {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill").font(.system(size: 11)).foregroundStyle(.white)
                    Text("\(state.battery)%").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(.white)
                }
            } else {
                Image(systemName: "bolt.fill").font(.system(size: 12)).foregroundStyle(.white)
            }
        } else {
            if state.isLong {
                Text(state.batteryRemaining).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(.white)
            } else {
                Text("\(state.battery)%").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(.white)
            }
        }
    }

    @ViewBuilder private var steps: some View {
        if size == .long {
            HStack(spacing: 6) {
                Image(systemName: "figure.walk").foregroundStyle(.white)
                Text("\(state.stepCount)").font(.system(size: 22, weight: .bold, design: .monospaced)).foregroundStyle(.white)
            }
        } else if slot == .leading {
            if state.isLong {
                HStack(spacing: 4) {
                    Image(systemName: "figure.walk").font(.system(size: 11)).foregroundStyle(.white)
                    Text("STEPS").font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(AnyShapeStyle(.secondary))
                }
            } else {
                Image(systemName: "figure.walk").font(.system(size: 12)).foregroundStyle(.white)
            }
        } else {
            Text("\(state.stepCount / 1000)k").font(.system(size: 13, weight: .semibold, design: .monospaced)).foregroundStyle(.white)
        }
    }

    @ViewBuilder private var memWatch: some View {
        if size == .long {
            HStack(spacing: 14) {
                valueLabel("MEM", String(format: "%.2fGB", state.memoryGB))
            }
        } else if slot == .leading {
            if state.isLong {
                HStack(spacing: 4) {
                    Text("MEM").font(.system(size: 11, design: .monospaced)).foregroundStyle(AnyShapeStyle(.secondary))
                    Text(String(format: "%.1f", state.memoryGB)).font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(.white)
                }
            } else {
                Text("MEM").font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(AnyShapeStyle(.secondary))
            }
        } else {
            Text(String(format: "%.1fGB", state.memoryGB)).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(.white)
        }
    }

    @ViewBuilder private var storageFree: some View {
        if size == .long {
            HStack(spacing: 14) {
                valueLabel("FREE", String(format: "%.0f GB", state.diskFreeGB))
                valueLabel("TOTAL", String(format: "%.0f GB", state.diskTotalGB))
            }
        } else if slot == .leading {
            if state.isLong {
                HStack(spacing: 4) {
                    Text("FREE").font(.system(size: 11, design: .monospaced)).foregroundStyle(AnyShapeStyle(.secondary))
                    Text(String(format: "%.0f", state.diskFreeGB)).font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(.white)
                }
            } else {
                Text("DISK").font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(AnyShapeStyle(.secondary))
            }
        } else {
            Text(String(format: "%.0fGB", state.diskFreeGB)).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(.white)
        }
    }

    @ViewBuilder private var worldClock: some View {
        if size == .long {
            HStack(spacing: 14) {
                valueLabel("SF", state.clockText)
                valueLabel("NY", addHours(state.clockText, by: 3))
                valueLabel("LDN", addHours(state.clockText, by: 8))
            }
        } else if slot == .leading {
            HStack(spacing: 4) {
                Text("SF").font(.system(size: 11, design: .monospaced)).foregroundStyle(AnyShapeStyle(.secondary))
                Text(state.clockText).font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(.white)
            }
        } else {
            HStack(spacing: 4) {
                Text("NY").font(.system(size: 11, design: .monospaced)).foregroundStyle(AnyShapeStyle(.secondary))
                Text(addHours(state.clockText, by: 3)).font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(.white)
            }
        }
    }

    private func addHours(_ clock: String, by hours: Int) -> String {
        let parts = clock.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return clock }
        let nh = ((h + hours) % 24 + 24) % 24
        return String(format: "%d:%02d", nh, m)
    }

    @ViewBuilder private var fallback: some View {
        Text(designId).font(.system(size: 11, design: .monospaced)).foregroundStyle(.white)
    }

    @ViewBuilder
    private func valueLabel(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(k).font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
            Text(v).font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundStyle(.white)
        }
    }
}

struct MinimalView: View {
    let designId: String
    let state: DesignAttributes.ContentState
    var body: some View {
        switch designId {
        case "framerate":     Text("\(state.fps)").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(.white)
        case "weather-now":   Image(systemName: state.weatherGlyph).foregroundStyle(.white)
        case "heart-rate":    Image(systemName: "heart.fill").foregroundStyle(.white)
        case "battery-watch": Image(systemName: "bolt.fill").foregroundStyle(.white)
        case "steps":         Image(systemName: "figure.walk").foregroundStyle(.white)
        case "big-clock":     Text(state.clockText).font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.white)
        case "memory-watch":  Text("M").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(.white)
        case "storage-free":  Image(systemName: "internaldrive").foregroundStyle(.white)
        case "world-clock":   Image(systemName: "globe").foregroundStyle(.white)
        case "cpu-thermal":   Text("\(state.cpu)").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(.white)
        default:              Circle().fill(.white).frame(width: 6, height: 6)
        }
    }
}

struct LockScreenView: View {
    let context: ActivityViewContext<DesignAttributes>
    var body: some View {
        HStack {
            WidgetContent(designId: context.attributes.designId, state: context.state, size: .long)
                .padding(16)
            Spacer()
        }
        .background(Color.black)
    }
}
