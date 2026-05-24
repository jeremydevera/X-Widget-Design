// LiveActivityManager · ActivityKit lifecycle + 1Hz live updates
//
// Call `apply(designId:)` when the user taps Apply on a live design.
// We immediately request a Live Activity and start a timer that pushes
// the latest DeviceMetrics snapshot into the activity's content state
// every second, so the Dynamic Island stays in sync with the app.

import ActivityKit
import Foundation
import UIKit
import Combine

@MainActor
final class LiveActivityManager: ObservableObject {
    static let shared = LiveActivityManager()
    private init() {}

    @Published private(set) var currentDesignId: String? = nil
    private var activity: Activity<DesignAttributes>? = nil
    private var ticker: AnyCancellable? = nil
    private weak var metricsRef: DeviceMetrics? = nil
    private var isLong: Bool = false

    /// Begin a Live Activity for the given design id. Reuses the metrics
    /// publisher to push updates every second.
    func apply(designId: String, metrics: DeviceMetrics, size: IslandSize = .short) async {
        await endAll()
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[Islet] Live Activities disabled in Settings → Islet")
            return
        }
        metricsRef = metrics
        isLong = (size == .long)
        let attrs = DesignAttributes(designId: designId)
        let initial = ActivityContent(state: snapshot(from: metrics), staleDate: nil)
        do {
            let a = try Activity.request(attributes: attrs, content: initial, pushType: nil)
            activity = a
            currentDesignId = designId
            startTicker()
            print("[Islet] Started Live Activity \(a.id) for \(designId)")
        } catch {
            print("[Islet] Failed to start Live Activity: \(error)")
        }
    }

    /// Stop the active Live Activity (if any).
    func endAll() async {
        ticker?.cancel(); ticker = nil
        for a in Activity<DesignAttributes>.activities {
            await a.end(nil, dismissalPolicy: .immediate)
        }
        activity = nil
        currentDesignId = nil
    }

    /// Push the latest metrics into the active activity.
    func tick() async {
        guard let a = activity, let m = metricsRef else { return }
        await a.update(ActivityContent(state: snapshot(from: m), staleDate: nil))
    }

    private func startTicker() {
        ticker?.cancel()
        ticker = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in await self?.tick() }
            }
    }

    /// Convert real DeviceMetrics into an ActivityKit ContentState payload.
    private func snapshot(from m: DeviceMetrics) -> DesignAttributes.ContentState {
        let now = Date()
        let cal = Calendar.current
        let h = cal.component(.hour, from: now)
        let mm = cal.component(.minute, from: now)
        return DesignAttributes.ContentState(
            clockText: String(format: "%d:%02d", h, mm),
            weatherTemp: 21,
            weatherGlyph: "sun.max.fill",
            cpu: Int(m.cpu),
            fps: Int(m.fps),
            temp: Double(thermalNumeric(m.thermal)),
            battery: Int(m.battery),
            batteryRemaining: m.batteryRemainingLabel,
            memoryGB: m.memUsedGB,
            diskFreeGB: m.diskFreeGB,
            diskTotalGB: m.diskTotalGB,
            heartRate: 72,
            stepCount: m.steps,
            workoutTimer: "",
            isLong: isLong
        )
    }

    private func thermalNumeric(_ s: ProcessInfo.ThermalState) -> Double {
        switch s {
        case .nominal:  return 35
        case .fair:     return 38
        case .serious:  return 42
        case .critical: return 46
        @unknown default: return 35
        }
    }
}
