import ActivityKit
import Foundation

/// ActivityAttributes payload shared between the main app and the widget extension.
/// `ContentState` carries the live-updating values (clock, weather temp, etc.).
/// `attributes.designId` selects which design's view to render in the Live Activity.
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
        public var memoryGB: Double
        public var heartRate: Int
        public var stepCount: Int
        public var workoutTimer: String

        public init(
            clockText: String = "9:41",
            weatherTemp: Int = 21,
            weatherGlyph: String = "sun.max.fill",
            cpu: Int = 42,
            fps: Int = 58,
            temp: Double = 38.5,
            battery: Int = 87,
            memoryGB: Double = 3.4,
            heartRate: Int = 72,
            stepCount: Int = 8243,
            workoutTimer: String = "23:14"
        ) {
            self.clockText = clockText
            self.weatherTemp = weatherTemp
            self.weatherGlyph = weatherGlyph
            self.cpu = cpu
            self.fps = fps
            self.temp = temp
            self.battery = battery
            self.memoryGB = memoryGB
            self.heartRate = heartRate
            self.stepCount = stepCount
            self.workoutTimer = workoutTimer
        }
    }

    /// Identifier of the design to render. Matches Design.id in the catalog.
    public var designId: String
}
