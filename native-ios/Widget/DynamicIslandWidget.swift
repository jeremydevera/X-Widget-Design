import ActivityKit
import SwiftUI
import WidgetKit

@main
struct IsletWidgetBundle: WidgetBundle {
    var body: some Widget {
        IsletLiveActivity()
    }
}

/// The Live Activity for displaying a design in the Dynamic Island & Lock Screen.
/// `attributes.designId` chooses which design view to render.
struct IsletLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DesignAttributes.self) { context in
            // Lock Screen / Banner view
            LockScreenView(context: context)
                .activityBackgroundTint(Color.black)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded — Apple-defined regions (leading, trailing, center, bottom)
                DynamicIslandExpandedRegion(.center) {
                    WidgetContent(designId: context.attributes.designId,
                                  state: context.state,
                                  size: .long)
                }
            } compactLeading: {
                WidgetContent(designId: context.attributes.designId,
                              state: context.state,
                              size: .short, slot: .leading)
            } compactTrailing: {
                WidgetContent(designId: context.attributes.designId,
                              state: context.state,
                              size: .short, slot: .trailing)
            } minimal: {
                MinimalView(designId: context.attributes.designId, state: context.state)
            }
        }
    }
}

// MARK: - Slot routing

enum WidgetSlot { case leading, trailing }

/// Apple's compact Dynamic Island has TWO slots (leading + trailing).
/// Each design decides what to show in each. For simplicity, leading = label-ish,
/// trailing = value-ish. The expanded version gets the full design.
struct WidgetContent: View {
    let designId: String
    let state: DesignAttributes.ContentState
    let size: WidgetSizeMode
    var slot: WidgetSlot? = nil

    var body: some View {
        switch designId {
        case "fps-counter":
            if size == .long {
                HStack(spacing: 6) {
                    Text("FPS").font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
                    Text("\(state.fps)").font(.system(size: 22, weight: .bold, design: .monospaced)).foregroundStyle(.white)
                }
            } else {
                Text(slot == .leading ? "FPS" : "\(state.fps)")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(slot == .leading ? Color.secondary : .white)
            }

        case "weather-now":
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

        case "heart-rate":
            if size == .long {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill").font(.system(size: 18)).foregroundStyle(.white)
                    Text("\(state.heartRate)").font(.system(size: 22, weight: .bold, design: .monospaced)).foregroundStyle(.white)
                    Text("BPM").font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
                }
            } else if slot == .leading {
                Image(systemName: "heart.fill").font(.system(size: 12)).foregroundStyle(.white)
            } else {
                Text("\(state.heartRate)").font(.system(size: 13, weight: .semibold, design: .monospaced)).foregroundStyle(.white)
            }

        case "cpu-temp":
            if size == .long {
                HStack(spacing: 14) {
                    valueLabel("CPU", "\(state.cpu)%")
                    valueLabel("TEMP", String(format: "%.1f°C", state.temp))
                    valueLabel("MEM", String(format: "%.1fGB", state.memoryGB))
                }
            } else if slot == .leading {
                Text("\(state.cpu)%").font(.system(size: 13, weight: .semibold, design: .monospaced)).foregroundStyle(.white)
            } else {
                Text(String(format: "%.0f°", state.temp)).font(.system(size: 13, weight: .semibold, design: .monospaced)).foregroundStyle(.white)
            }

        case "big-clock":
            Text(state.clockText).font(.system(size: size == .long ? 32 : 14, weight: .bold, design: .monospaced)).foregroundStyle(.white)

        case "battery-watch":
            if size == .long {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill").font(.system(size: 18)).foregroundStyle(.white)
                    Text("\(state.battery)%").font(.system(size: 22, weight: .bold, design: .monospaced)).foregroundStyle(.white)
                }
            } else if slot == .leading {
                Image(systemName: "bolt.fill").font(.system(size: 12)).foregroundStyle(.white)
            } else {
                Text("\(state.battery)%").font(.system(size: 13, weight: .semibold, design: .monospaced)).foregroundStyle(.white)
            }

        case "steps":
            if size == .long {
                HStack(spacing: 6) {
                    Image(systemName: "figure.walk").font(.system(size: 18)).foregroundStyle(.white)
                    Text("\(state.stepCount)").font(.system(size: 22, weight: .bold, design: .monospaced)).foregroundStyle(.white)
                }
            } else if slot == .leading {
                Image(systemName: "figure.walk").font(.system(size: 12)).foregroundStyle(.white)
            } else {
                Text("\(state.stepCount / 1000)k").font(.system(size: 13, weight: .semibold, design: .monospaced)).foregroundStyle(.white)
            }

        case "workout":
            if size == .long {
                HStack(spacing: 6) {
                    Image(systemName: "figure.run").font(.system(size: 18)).foregroundStyle(.white)
                    Text(state.workoutTimer).font(.system(size: 22, weight: .bold, design: .monospaced)).foregroundStyle(.white)
                }
            } else if slot == .leading {
                Image(systemName: "figure.run").font(.system(size: 12)).foregroundStyle(.white)
            } else {
                Text(state.workoutTimer).font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundStyle(.white)
            }

        case "minimal-pulse":
            Circle().fill(.white).frame(width: size == .long ? 14 : 8, height: size == .long ? 14 : 8)

        default:
            Text(designId).font(.system(size: 11, design: .monospaced)).foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private func valueLabel(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(k).font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
            Text(v).font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundStyle(.white)
        }
    }
}

enum WidgetSizeMode { case short, long }

struct MinimalView: View {
    let designId: String
    let state: DesignAttributes.ContentState
    var body: some View {
        switch designId {
        case "fps-counter":   Text("\(state.fps)").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(.white)
        case "weather-now":   Image(systemName: state.weatherGlyph).foregroundStyle(.white)
        case "heart-rate":    Image(systemName: "heart.fill").foregroundStyle(.white)
        case "battery-watch": Image(systemName: "bolt.fill").foregroundStyle(.white)
        case "steps":         Image(systemName: "figure.walk").foregroundStyle(.white)
        case "workout":       Image(systemName: "figure.run").foregroundStyle(.white)
        case "big-clock":     Text(state.clockText).font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.white)
        default:              Circle().fill(.white).frame(width: 6, height: 6)
        }
    }
}

// MARK: - Lock Screen view

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
