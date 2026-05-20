import SwiftUI

/// Builds the SwiftUI view for any design id. Used in:
///  - In-app preview frame
///  - Mini list-row preview
///  - The Live Activity (via DynamicIslandWidget switching on the same id)
///
/// `size` controls compact vs long. LONG = same content, just more horizontal padding/gap.
struct DesignView: View {
    let designId: String
    let size: SizeMode
    let ctx: LiveContext

    var body: some View {
        switch designId {
        case "fps-counter":   FPSCounterView(ctx: ctx, size: size)
        case "cpu-temp":      CPUTempView(ctx: ctx, size: size)
        case "download":      DownloadView(size: size)
        case "battery-watch": BatteryWatchView(ctx: ctx, size: size)
        case "now-playing":   NowPlayingView(size: size)
        case "recording":     RecordingView(ctx: ctx, size: size)
        case "live-stream":   LiveStreamView(size: size)
        case "weather-now":   WeatherNowView(ctx: ctx, size: size)
        case "weather-clock": WeatherClockView(ctx: ctx, size: size)
        case "heart-rate":    HeartRateView(ctx: ctx, size: size)
        case "steps":         StepsView(ctx: ctx, size: size)
        case "workout":       WorkoutView(ctx: ctx, size: size)
        case "big-clock":     BigClockView(ctx: ctx, size: size)
        case "sample-gif":    SampleGifView(size: size)
        case "minimal-pulse": MinimalPulseView(size: size)
        default:              EmptyView()
        }
    }
}

// MARK: - Shared widget primitives

/// A "value pill" — small label + big value + small unit, monospaced.
struct WPill: View {
    let label: String?
    let value: String
    let unit: String?
    var bigValue: Bool = false
    var body: some View {
        HStack(spacing: 4) {
            if let label, !label.isEmpty {
                Text(label).font(Theme.mono(9, weight: .medium)).foregroundStyle(Theme.text3)
            }
            Text(value).font(Theme.mono(bigValue ? 14 : 12, weight: .semibold)).foregroundStyle(Theme.hi)
            if let unit, !unit.isEmpty {
                Text(unit).font(Theme.mono(9, weight: .medium)).foregroundStyle(Theme.text3)
            }
        }
        .lineLimit(1)
    }
}

/// Pulsing dot — used for live indicators.
struct PulseDot: View {
    var size: CGFloat = 7
    var color: Color = Theme.hi
    @State private var on = true
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .shadow(color: color.opacity(on ? 0.8 : 0), radius: on ? 5 : 0)
            .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: on)
            .onAppear { on.toggle() }
    }
}

/// Small spinning ring — download / loading.
struct Spinner: View {
    var size: CGFloat = 12
    @State private var spin = false
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(Theme.hi, style: .init(lineWidth: 1.5, lineCap: .round))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(spin ? 360 : 0))
            .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: spin)
            .onAppear { spin.toggle() }
    }
}

/// Audio bars — animated equalizer columns.
struct AudioBars: View {
    var height: CGFloat = 12
    @State private var t = false
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(Theme.hi)
                    .frame(width: 2, height: t ? height * heights[i] : height * 0.4)
                    .animation(
                        .easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true)
                        .delay(Double(i) * 0.07),
                        value: t
                    )
            }
        }
        .frame(height: height)
        .onAppear { t.toggle() }
    }
    private let heights: [CGFloat] = [0.6, 0.8, 1.0, 0.7, 0.5]
}

/// A shimmer block as a stand-in for a GIF / animated sticker.
struct ShimmerTile: View {
    let label: String
    var size: CGFloat = 22
    @State private var phase = false
    var body: some View {
        LinearGradient(
            colors: [Color(hex: 0x444), Color(hex: 0xAAA), Color(hex: 0x555)],
            startPoint: phase ? .topLeading : .bottomTrailing,
            endPoint:   phase ? .bottomTrailing : .topLeading
        )
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            Text(label).font(Theme.mono(size * 0.5, weight: .bold)).foregroundStyle(.black)
        )
        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: phase)
        .onAppear { phase.toggle() }
    }
}

/// Animated progress bar.
struct ProgressPulse: View {
    var width: CGFloat = 36
    var height: CGFloat = 3
    @State private var w: CGFloat = 0.12
    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle().fill(Theme.text4).frame(width: width, height: height)
            Rectangle().fill(Theme.hi).frame(width: width * w, height: height)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: w)
        .onAppear { w = 0.78 }
    }
}

// MARK: - Designs (each one)
// Each implements compact (`short`) and long. LONG = same content, just wider gaps.

private func gapFor(_ size: SizeMode) -> CGFloat { size == .long ? 28 : 14 }
private func padFor(_ size: SizeMode) -> CGFloat { size == .long ? 36 : 18 }

private struct PillFrame<Content: View>: View {
    let size: SizeMode
    @ViewBuilder var content: () -> Content
    var body: some View {
        HStack(spacing: gapFor(size)) { content() }
            .padding(.horizontal, padFor(size))
            .frame(height: 44)
            .frame(minWidth: size == .long ? 320 : 160)
            .background(.black, in: Capsule())
    }
}

// ─── DEVICE

struct FPSCounterView: View {
    let ctx: LiveContext; let size: SizeMode
    var body: some View {
        PillFrame(size: size) {
            WPill(label: "fps", value: "\(Int(ctx.fps))", unit: nil, bigValue: true)
        }
    }
}

struct CPUTempView: View {
    let ctx: LiveContext; let size: SizeMode
    var body: some View {
        PillFrame(size: size) {
            WPill(label: "cpu", value: "\(Int(ctx.cpu))%", unit: nil)
            WPill(label: "°c",  value: String(format: "%.1f", ctx.temp), unit: nil)
        }
    }
}

struct DownloadView: View {
    let size: SizeMode
    var body: some View {
        PillFrame(size: size) {
            Spinner(size: 14)
            WPill(label: nil, value: "64%", unit: nil)
        }
    }
}

struct BatteryWatchView: View {
    let ctx: LiveContext; let size: SizeMode
    var body: some View {
        PillFrame(size: size) {
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill").font(.system(size: 11)).foregroundStyle(Theme.text3)
                WPill(label: nil, value: "\(Int(ctx.battery))%", unit: nil)
            }
            PulseDot()
        }
    }
}

// ─── MEDIA

struct NowPlayingView: View {
    let size: SizeMode
    var body: some View {
        PillFrame(size: size) {
            ShimmerTile(label: "♪", size: 22)
            AudioBars(height: 14)
        }
    }
}

struct RecordingView: View {
    let ctx: LiveContext; let size: SizeMode
    var body: some View {
        PillFrame(size: size) {
            HStack(spacing: 5) {
                PulseDot()
                Text("REC").font(Theme.mono(11, weight: .semibold)).foregroundStyle(Theme.hi)
            }
            Text(ctx.clockText).font(Theme.mono(12, weight: .semibold)).foregroundStyle(Theme.hi)
        }
    }
}

struct LiveStreamView: View {
    let size: SizeMode
    var body: some View {
        PillFrame(size: size) {
            HStack(spacing: 5) {
                PulseDot(size: 6, color: .black)
                Text("LIVE").font(Theme.mono(10, weight: .bold)).foregroundStyle(.black)
            }
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(Theme.hi, in: Capsule())

            WPill(label: nil, value: "1.2K", unit: nil)
        }
    }
}

// ─── WEATHER

struct WeatherNowView: View {
    let ctx: LiveContext; let size: SizeMode
    var body: some View {
        PillFrame(size: size) {
            HStack(spacing: 5) {
                Image(systemName: ctx.weatherGlyph).font(.system(size: 14)).foregroundStyle(Theme.hi)
                Text("\(Int(ctx.weatherTemp))°").font(Theme.mono(13, weight: .semibold)).foregroundStyle(Theme.hi)
            }
        }
    }
}

struct WeatherClockView: View {
    let ctx: LiveContext; let size: SizeMode
    var body: some View {
        PillFrame(size: size) {
            Text(ctx.clockText).font(Theme.mono(13, weight: .semibold)).foregroundStyle(Theme.hi)
            HStack(spacing: 5) {
                Image(systemName: ctx.weatherGlyph).font(.system(size: 13)).foregroundStyle(Theme.hi)
                Text("\(Int(ctx.weatherTemp))°").font(Theme.mono(13, weight: .semibold)).foregroundStyle(Theme.hi)
            }
        }
    }
}

// ─── HEALTH

struct HeartRateView: View {
    let ctx: LiveContext; let size: SizeMode
    var body: some View {
        PillFrame(size: size) {
            PulseDot()
            WPill(label: nil, value: "\(ctx.heartRate)", unit: "BPM")
        }
    }
}

struct StepsView: View {
    let ctx: LiveContext; let size: SizeMode
    var body: some View {
        PillFrame(size: size) {
            WPill(label: "steps", value: "\(ctx.stepCount.formatted(.number))", unit: nil)
        }
    }
}

struct WorkoutView: View {
    let ctx: LiveContext; let size: SizeMode
    var body: some View {
        PillFrame(size: size) {
            WPill(label: "run", value: ctx.workoutTimer, unit: nil, bigValue: true)
        }
    }
}

// ─── TIME

struct BigClockView: View {
    let ctx: LiveContext; let size: SizeMode
    var body: some View {
        PillFrame(size: size) {
            Text(ctx.clockText).font(Theme.mono(16, weight: .bold)).foregroundStyle(Theme.hi)
        }
    }
}

// ─── FUN

struct SampleGifView: View {
    let size: SizeMode
    var body: some View {
        PillFrame(size: size) {
            ShimmerTile(label: "▶", size: 22)
            Text("LOOP").font(Theme.mono(11, weight: .semibold)).foregroundStyle(Theme.hi)
        }
    }
}

struct MinimalPulseView: View {
    let size: SizeMode
    var body: some View {
        PillFrame(size: size) { PulseDot(size: 9) }
    }
}
