// DesignAttributes · ActivityKit payload shared between the main app
// and the Widget extension.

import ActivityKit
import Foundation

struct DesignAttributes: ActivityAttributes {
    public typealias DesignContentState = ContentState

    public struct ContentState: Codable, Hashable {
        public var clockText: String
        public var weatherTemp: Int
        public var weatherGlyph: String
        public var cpu: Int
        public var fps: Int
        public var temp: Double
        public var battery: Int
        public var batteryRemaining: String
        public var memoryGB: Double
        public var diskFreeGB: Double
        public var diskTotalGB: Double
        public var heartRate: Int
        public var stepCount: Int
        public var workoutTimer: String
        public var isLong: Bool

        public init(
            clockText: String = "9:41",
            weatherTemp: Int = 21,
            weatherGlyph: String = "sun.max.fill",
            cpu: Int = 42,
            fps: Int = 60,
            temp: Double = 38.5,
            battery: Int = 87,
            batteryRemaining: String = "—",
            memoryGB: Double = 1.8,
            diskFreeGB: Double = 0,
            diskTotalGB: Double = 0,
            heartRate: Int = 72,
            stepCount: Int = 8243,
            workoutTimer: String = "23:14",
            isLong: Bool = false
        ) {
            self.clockText = clockText
            self.weatherTemp = weatherTemp
            self.weatherGlyph = weatherGlyph
            self.cpu = cpu
            self.fps = fps
            self.temp = temp
            self.battery = battery
            self.batteryRemaining = batteryRemaining
            self.memoryGB = memoryGB
            self.diskFreeGB = diskFreeGB
            self.diskTotalGB = diskTotalGB
            self.heartRate = heartRate
            self.stepCount = stepCount
            self.workoutTimer = workoutTimer
            self.isLong = isLong
        }
    }

    public var designId: String
}
