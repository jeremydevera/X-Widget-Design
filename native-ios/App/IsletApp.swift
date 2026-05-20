import SwiftUI

@main
struct IsletApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}

/// Global state for the browse → preview → apply flow.
/// Mirrors the JS `state` object from the HTML prototype.
@MainActor
final class AppStore: ObservableObject {
    @Published var focusedId: String = "weather-now"
    @Published var appliedId: String = "weather-now"
    @Published var size: SizeMode = .short
    @Published var filter: FilterKey = .all
    @Published var ctx: LiveContext = .init()

    private var tickTask: Task<Void, Never>?

    init() {
        startTicking()
    }

    func startTicking() {
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self?.tick()
            }
        }
    }

    private func tick() {
        // Mean-reverting random walk for the mock metrics
        ctx.cpu     = clamp(ctx.cpu     + jitter(span: 6),   8, 98)
        ctx.fps     = clamp(ctx.fps     + jitter(span: 5),  30, 120)
        ctx.temp    = clamp(ctx.temp    + jitter(span: 0.3), 32, 48)
        ctx.battery = clamp(ctx.battery + jitter(span: 0.2), 10, 100)
        ctx.memoryGB = clamp(ctx.memoryGB + jitter(span: 0.12), 2.0, 5.5)

        let now = Date()
        let f = DateFormatter()
        f.dateFormat = "H:mm"
        ctx.clockText = f.string(from: now)

        // If a Live Activity is running, push an update
        Task { await LiveActivityManager.shared.update(with: ctx) }
    }

    func apply() {
        appliedId = focusedId
        Task { await LiveActivityManager.shared.start(designId: focusedId, ctx: ctx) }
    }

    func dismissActive() {
        appliedId = ""
        Task { await LiveActivityManager.shared.endAll() }
    }
}

enum SizeMode: String, CaseIterable, Identifiable {
    case short, long
    var id: String { rawValue }
    var label: String { rawValue.uppercased() }
}

enum FilterKey: Hashable {
    case all
    case category(String)

    var label: String {
        switch self {
        case .all: return "ALL"
        case .category(let c): return c
        }
    }
}

/// Mock context that drives every widget's display values.
struct LiveContext {
    var clockText: String = "9:41"
    var weatherTemp: Double = 21
    var weatherGlyph: String = "sun.max.fill"
    var cpu: Double = 42
    var fps: Double = 58
    var temp: Double = 38.5
    var battery: Double = 87
    var memoryGB: Double = 3.4
    var heartRate: Int = 72
    var stepCount: Int = 8243
    var workoutTimer: String = "23:14"

    /// Convert to the codable ContentState pushed into the Live Activity.
    func asContentState() -> DesignAttributes.ContentState {
        .init(
            clockText: clockText,
            weatherTemp: Int(weatherTemp.rounded()),
            weatherGlyph: weatherGlyph,
            cpu: Int(cpu.rounded()),
            fps: Int(fps.rounded()),
            temp: temp,
            battery: Int(battery.rounded()),
            memoryGB: memoryGB,
            heartRate: heartRate,
            stepCount: stepCount,
            workoutTimer: workoutTimer
        )
    }
}

@inline(__always)
private func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double { max(lo, min(hi, v)) }

@inline(__always)
private func jitter(span: Double) -> Double { (Double.random(in: 0...1) - 0.5) * span }
