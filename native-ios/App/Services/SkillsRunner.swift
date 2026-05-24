// SkillsRunner · evaluates enabled skills against live device state.
//
// Wired skills (fire while the app is in the foreground):
//   b-100      full charge alert
//   b-low      low battery warning
//   b-80stop   stop charging at 80% reminder
//   h-water    hydrate every N minutes during work hours
//   h-steps    daily step goal celebration
//   p-thermal  thermal state warning
//   p-storage  storage cleanup warning
//
// Other skills are best run via the App Intents the user wires up in
// the Shortcuts app (see SkillsTab's "Run via Shortcuts" card).

import Foundation
import UIKit
import UserNotifications
import Combine

@MainActor
final class SkillsRunner: ObservableObject {
    private let state: AppState
    private let metrics: DeviceMetrics
    private var cancellables = Set<AnyCancellable>()

    // Latches · prevent skills from firing repeatedly while a condition holds.
    private var b100Fired: Bool = false
    private var bLowFired: Bool = false
    private var b80StopFired: Bool = false
    private var hStepsFired: Bool = false
    private var pThermalFired: Bool = false
    private var pStorageFired: Bool = false
    private var hWaterTimer: AnyCancellable?

    init(state: AppState, metrics: DeviceMetrics) {
        self.state = state
        self.metrics = metrics
        requestNotificationPermissionIfNeeded()
        observe()
    }

    // MARK: notification permission
    private func requestNotificationPermissionIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
    }

    // MARK: observation
    private func observe() {
        // Re-evaluate every time battery, steps, thermal, or storage change
        metrics.$battery.removeDuplicates().sink { [weak self] _ in self?.evaluate() }.store(in: &cancellables)
        metrics.$batteryState.sink { [weak self] _ in self?.evaluate() }.store(in: &cancellables)
        metrics.$steps.removeDuplicates().sink { [weak self] _ in self?.evaluate() }.store(in: &cancellables)
        metrics.$thermal.sink { [weak self] _ in self?.evaluate() }.store(in: &cancellables)
        metrics.$diskFreeGB.removeDuplicates().sink { [weak self] _ in self?.evaluate() }.store(in: &cancellables)

        // Reset latches when skills are toggled off
        state.$enabledSkills.sink { [weak self] _ in self?.resetLatchesForDisabled() }.store(in: &cancellables)
        // (Re)start the hydrate timer whenever the skill is toggled
        state.$enabledSkills.sink { [weak self] _ in self?.refreshWaterTimer() }.store(in: &cancellables)
        refreshWaterTimer()
    }

    private func resetLatchesForDisabled() {
        if !state.isSkillOn("b-100")    { b100Fired = false }
        if !state.isSkillOn("b-low")    { bLowFired = false }
        if !state.isSkillOn("b-80stop") { b80StopFired = false }
        if !state.isSkillOn("h-steps")  { hStepsFired = false }
        if !state.isSkillOn("p-thermal"){ pThermalFired = false }
        if !state.isSkillOn("p-storage"){ pStorageFired = false }
    }

    // MARK: master evaluator
    private func evaluate() {
        let level = Int(metrics.battery.rounded())

        // ─ b-100 · full charge alert
        if state.isSkillOn("b-100") {
            let threshold = configInt("b-100", "threshold", default: 100)
            if level >= threshold && !b100Fired && metrics.batteryState != .unknown {
                fireNotification(title: "Battery charged",
                                 body: threshold == 100 ? "Battery is full · unplug to extend battery life."
                                                       : "Charge reached \(threshold)% · consider unplugging.")
                b100Fired = true
            }
            if level < threshold - 3 { b100Fired = false }
        }

        // ─ b-low · low battery warning
        if state.isSkillOn("b-low") {
            let threshold = configInt("b-low", "threshold", default: 20)
            if level <= threshold && !bLowFired {
                fireNotification(title: "Battery low",
                                 body: "Down to \(level)% · enable Low Power Mode and dim brightness.")
                bLowFired = true
            }
            if level > threshold + 5 { bLowFired = false }
        }

        // ─ b-80stop · stop charging at 80% reminder
        if state.isSkillOn("b-80stop") {
            let threshold = configInt("b-80stop", "threshold", default: 80)
            if level >= threshold && metrics.batteryState == .charging && !b80StopFired {
                fireNotification(title: "Unplug to extend battery life",
                                 body: "Reached \(threshold)% while charging.")
                b80StopFired = true
            }
            if level < threshold - 3 || metrics.batteryState != .charging { b80StopFired = false }
        }

        // ─ h-steps · daily step goal
        if state.isSkillOn("h-steps") {
            let goal = configInt("h-steps", "goal", default: 10000)
            if metrics.steps >= goal && !hStepsFired {
                fireNotification(title: "Daily step goal reached",
                                 body: "You hit \(metrics.steps.formatted(.number)) steps · nice work.",
                                 sound: true)
                hStepsFired = true
            }
        }

        // ─ p-thermal · device too hot
        if state.isSkillOn("p-thermal") {
            let level = configString("p-thermal", "level", default: "serious")
            let isHit = (level == "fair"     && metrics.thermal == .fair) ||
                        (level == "serious"  && (metrics.thermal == .serious || metrics.thermal == .critical)) ||
                        (level == "critical" && metrics.thermal == .critical)
            if isHit && !pThermalFired {
                fireNotification(title: "Device is \(metrics.thermal.friendly)",
                                 body: "Close background apps · iOS may throttle performance.")
                pThermalFired = true
            }
            if metrics.thermal == .nominal { pThermalFired = false }
        }

        // ─ p-storage · running out of space
        if state.isSkillOn("p-storage") {
            let gb = configDouble("p-storage", "gb", default: 5)
            if metrics.diskFreeGB > 0 && metrics.diskFreeGB < gb && !pStorageFired {
                fireNotification(title: "Storage low",
                                 body: "Only \(String(format: "%.1f", metrics.diskFreeGB)) GB free · open Photos to clean up duplicates.")
                pStorageFired = true
            }
            if metrics.diskFreeGB > gb + 1 { pStorageFired = false }
        }
    }

    // MARK: hydrate timer
    private func refreshWaterTimer() {
        hWaterTimer?.cancel()
        hWaterTimer = nil
        guard state.isSkillOn("h-water") else { return }
        let interval = configInt("h-water", "interval", default: 90)  // minutes
        hWaterTimer = Timer.publish(every: TimeInterval(interval * 60), on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                if self.isWithinWaterWindow() {
                    self.fireNotification(title: "Hydrate", body: "Drink some water · interval reminder.")
                }
            }
    }

    private func isWithinWaterWindow() -> Bool {
        let start = configString("h-water", "start", default: "09:00")
        let end   = configString("h-water", "end",   default: "18:00")
        guard let s = parseHM(start), let e = parseHM(end) else { return true }
        let now = Date()
        let cal = Calendar.current
        let h = cal.component(.hour, from: now)
        let m = cal.component(.minute, from: now)
        let nowMins = h * 60 + m
        let startMins = s.h * 60 + s.m
        let endMins = e.h * 60 + e.m
        return nowMins >= startMins && nowMins <= endMins
    }

    private func parseHM(_ s: String) -> (h: Int, m: Int)? {
        let parts = s.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        return (h, m)
    }

    // MARK: notification firing
    private func fireNotification(title: String, body: String, sound: Bool = false) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if sound { content.sound = .default }
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)

        // Subtle haptic for non-critical alerts
        let g = UINotificationFeedbackGenerator()
        g.notificationOccurred(.success)
    }

    // MARK: config helpers
    private func configInt(_ id: String, _ key: String, default def: Int) -> Int {
        guard let raw = state.skillConfigs[id]?[key] else { return def }
        switch raw {
        case .int(let v):    return v
        case .double(let v): return Int(v)
        default:             return def
        }
    }
    private func configDouble(_ id: String, _ key: String, default def: Double) -> Double {
        guard let raw = state.skillConfigs[id]?[key] else { return def }
        switch raw {
        case .int(let v):    return Double(v)
        case .double(let v): return v
        default:             return def
        }
    }
    private func configString(_ id: String, _ key: String, default def: String) -> String {
        guard let raw = state.skillConfigs[id]?[key] else { return def }
        if case .string(let v) = raw { return v }
        return def
    }
}
