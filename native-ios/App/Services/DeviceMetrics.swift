// DeviceMetrics · live snapshot of measurable iOS metrics
//
// All values come from real public iOS APIs. Polled on the main queue.
// Sensors that require permission only emit values after the user grants
// access (Motion, Location). CPU temperature in °C is intentionally absent
// — Apple does not expose it; thermal state enum is the honest reading.

import Foundation
import UIKit
import Combine
import Network
import Darwin
import CoreMotion
import CoreLocation
import CoreTelephony
import AVFAudio

@MainActor
final class DeviceMetrics: NSObject, ObservableObject {

    // ─ Compute
    @Published var cpu: Double = 0
    @Published var memUsedGB: Double = 0
    @Published var memTotalGB: Double = 0
    @Published var memActiveGB: Double = 0
    @Published var memWiredGB: Double = 0
    @Published var memCompressedGB: Double = 0
    @Published var memFreeGB: Double = 0
    @Published var memAppGB: Double = 0          // this app's footprint, kept for reference
    @Published var thermal: ProcessInfo.ThermalState = .nominal
    @Published var battery: Double = 100
    @Published var batteryState: UIDevice.BatteryState = .unknown
    /// % per hour drain (positive = battery losing). nil = not enough samples yet.
    @Published var batteryDrainPerHour: Double? = nil
    /// Estimated hours remaining at the current drain rate. nil = unknown / charging.
    @Published var batteryHoursRemaining: Double? = nil
    @Published var diskFreeGB: Double = 0
    @Published var diskTotalGB: Double = 0
    @Published var cores: Int = 0
    @Published var coresTotal: Int = 0

    // ─ Display & audio
    @Published var fps: Double = 0
    @Published var brightness: Double = 0
    @Published var volume: Double = 0

    // ─ Sensors
    @Published var pressureHpa: Double = 0
    @Published var altitudeM: Double = 0
    @Published var heading: Double = 0
    @Published var accelX: Double = 0
    @Published var accelY: Double = 0
    @Published var accelZ: Double = 0
    @Published var gyroX: Double = 0
    @Published var gyroY: Double = 0
    @Published var gyroZ: Double = 0
    @Published var steps: Int = 0
    @Published var distanceKm: Double = 0
    @Published var proximityNear: Bool = false

    // ─ Environment
    @Published var uptime: TimeInterval = 0
    @Published var lowPower: Bool = false
    @Published var refreshHz: Int = 60
    @Published var network: NetworkType = .none
    @Published var cellTech: String = "—"
    @Published var deviceModel: String = "iPhone"
    @Published var chip: String = "—"
    @Published var iosVersion: String = ""
    @Published var ramGB: Double = 0
    @Published var displayRes: String = ""
    @Published var locale: String = ""
    @Published var timeZone: String = ""

    // ─ Today peaks (tracked while app is active)
    @Published var todayCpuPeak: Double = 0
    @Published var todayThermalPeak: ProcessInfo.ThermalState = .nominal

    // ─ Rolling 60-second CPU history (for Performance graph)
    @Published private(set) var cpuHistory: [Double] = []
    @Published private(set) var memHistory: [Double] = []
    private let cpuHistoryMax = 60

    enum NetworkType: String { case wifi, cellular, wired, none }

    // Real-iOS plumbing
    private var timer: AnyCancellable?
    private var displayLink: CADisplayLink?
    private var pathMonitor: NWPathMonitor?
    private var motionManager: CMMotionManager?
    private var altimeter: CMAltimeter?
    private var locationManager: CLLocationManager?
    private var pedometer: CMPedometer?
    private var lastCpuTicks: (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)?
    private var frameCount: Int = 0
    private var lastFrameSampleTime: CFTimeInterval = 0

    override init() {
        super.init()
        UIDevice.current.isBatteryMonitoringEnabled = true
        UIDevice.current.isProximityMonitoringEnabled = true
        readStaticInfo()
        readDiskCapacity()

        startNetworkMonitor()
        startDisplayLink()
        startMotionUpdates()
        startAltimeter()
        startCompass()
        startPedometer()
        startVolumeObserver()
        observeProximity()

        sampleAll()
        timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in self?.sampleAll() }
    }

    deinit {
        Task { @MainActor [weak self] in
            self?.displayLink?.invalidate()
            self?.pathMonitor?.cancel()
            self?.motionManager?.stopAccelerometerUpdates()
            self?.motionManager?.stopGyroUpdates()
            self?.altimeter?.stopRelativeAltitudeUpdates()
            self?.locationManager?.stopUpdatingHeading()
            self?.pedometer?.stopUpdates()
        }
    }

    // ─ MARK: per-tick snapshot
    private func sampleAll() {
        cpu = readCpuPercent()
        cpuHistory.append(cpu)
        if cpuHistory.count > cpuHistoryMax { cpuHistory.removeFirst(cpuHistory.count - cpuHistoryMax) }
        if cpu > todayCpuPeak { todayCpuPeak = cpu }

        let m = readSystemMemory()
        memActiveGB = m.active
        memWiredGB = m.wired
        memCompressedGB = m.compressed
        memFreeGB = m.free
        memUsedGB = m.active + m.wired + m.compressed
        memTotalGB = m.total
        ramGB = m.total
        memAppGB = readAppFootprintGB()
        memHistory.append(memUsedGB)
        if memHistory.count > cpuHistoryMax { memHistory.removeFirst(memHistory.count - cpuHistoryMax) }

        thermal = ProcessInfo.processInfo.thermalState
        if thermalRank(thermal) > thermalRank(todayThermalPeak) { todayThermalPeak = thermal }

        // UIDevice.batteryLevel returns a Float between 0..1 but snaps to
        // 5% increments only (this is iOS's public-API resolution; the
        // status bar uses a private API for finer values). We round() rather
        // than truncate so 0.7499999 (the float-rounded 75%) reads as 75 not 74.
        let raw = UIDevice.current.batteryLevel
        if raw < 0 {
            battery = 0  // -1.0 means unknown (e.g. simulator)
        } else {
            battery = max(0, (Double(raw) * 100).rounded())
        }
        batteryState = UIDevice.current.batteryState

        recordBatterySample()
        cores = ProcessInfo.processInfo.activeProcessorCount
        coresTotal = ProcessInfo.processInfo.processorCount
        uptime = ProcessInfo.processInfo.systemUptime
        lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        refreshHz = UIScreen.main.maximumFramesPerSecond
        brightness = Double(UIScreen.main.brightness) * 100
        proximityNear = UIDevice.current.proximityState
    }

    private func thermalRank(_ s: ProcessInfo.ThermalState) -> Int {
        switch s {
        case .nominal: return 1; case .fair: return 2
        case .serious: return 3; case .critical: return 4
        @unknown default: return 1
        }
    }

    // ─ MARK: CPU · host_processor_info delta
    private func readCpuPercent() -> Double {
        var cpuLoad = host_cpu_load_info()
        var size = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let host = mach_host_self()
        let kr = withUnsafeMutablePointer(to: &cpuLoad) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &size)
            }
        }
        guard kr == KERN_SUCCESS else { return cpu }
        let user = UInt32(cpuLoad.cpu_ticks.0)
        let system = UInt32(cpuLoad.cpu_ticks.1)
        let idle = UInt32(cpuLoad.cpu_ticks.2)
        let nice = UInt32(cpuLoad.cpu_ticks.3)
        defer { lastCpuTicks = (user, system, idle, nice) }
        guard let prev = lastCpuTicks else { return 0 }
        let dUser   = Double(user &- prev.user)
        let dSystem = Double(system &- prev.system)
        let dIdle   = Double(idle &- prev.idle)
        let dNice   = Double(nice &- prev.nice)
        let total = dUser + dSystem + dIdle + dNice
        guard total > 0 else { return cpu }
        let busy = dUser + dSystem + dNice
        return min(100, max(0, busy / total * 100))
    }

    // ─ MARK: System memory · host_statistics64(HOST_VM_INFO64)
    // Returns active + wired + compressed + free in GB, plus total RAM.
    private func readSystemMemory() -> (active: Double, wired: Double, compressed: Double, free: Double, total: Double) {
        var stats = vm_statistics64_data_t()
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let host = mach_host_self()
        let kr = withUnsafeMutablePointer(to: &stats) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &size)
            }
        }
        let pageSize = Double(vm_kernel_page_size)
        let toGB: (UInt64) -> Double = { Double($0) * pageSize / 1_073_741_824 }
        let total = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        guard kr == KERN_SUCCESS else {
            return (0, 0, 0, 0, total)
        }
        let active = toGB(UInt64(stats.active_count))
        let wired  = toGB(UInt64(stats.wire_count))
        let compressed = toGB(UInt64(stats.compressor_page_count))
        // "free" iOS-style: free + inactive + speculative (these are reusable pages)
        let free = toGB(UInt64(stats.free_count) + UInt64(stats.inactive_count) + UInt64(stats.speculative_count))
        return (active, wired, compressed, free, total)
    }

    // ─ MARK: Battery samples · drives drainPerHour + hoursRemaining
    private struct BatterySample { let t: Date; let level: Double }
    private var batterySamples: [BatterySample] = []

    private func recordBatterySample() {
        let now = Date()
        // Keep up to 30 samples (~5 min at 1Hz, after that we slide)
        batterySamples.append(BatterySample(t: now, level: battery))
        if batterySamples.count > 30 { batterySamples.removeFirst() }

        // Don't emit a drain rate while charging
        if batteryState == .charging || batteryState == .full {
            batteryDrainPerHour = nil
            batteryHoursRemaining = nil
            return
        }

        // Need at least 30 seconds of data + a measurable drop
        guard let oldest = batterySamples.first,
              let newest = batterySamples.last,
              newest.t.timeIntervalSince(oldest.t) >= 30 else {
            batteryDrainPerHour = nil
            batteryHoursRemaining = nil
            return
        }

        let elapsedHours = newest.t.timeIntervalSince(oldest.t) / 3600.0
        let drop = oldest.level - newest.level
        guard drop > 0, elapsedHours > 0 else {
            // Battery is steady — no drain to report
            batteryDrainPerHour = 0
            batteryHoursRemaining = nil
            return
        }
        let perHour = drop / elapsedHours
        batteryDrainPerHour = perHour
        batteryHoursRemaining = battery / perHour
    }

    // ─ MARK: This app's footprint · mach_task_basic_info (kept for the dashboard)
    private func readAppFootprintGB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info_data_t>.size) / 4
        let kr = withUnsafeMutablePointer(to: &info) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return kr == KERN_SUCCESS ? Double(info.resident_size) / 1_073_741_824 : 0
    }

    // ─ MARK: Disk · URLResourceValues
    private func readDiskCapacity() {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        if let v = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey,
                                                     .volumeTotalCapacityKey]) {
            if let total = v.volumeTotalCapacity {
                diskTotalGB = Double(total) / 1_073_741_824
            }
            if let imp = v.volumeAvailableCapacityForImportantUsage {
                diskFreeGB = Double(imp) / 1_073_741_824
            }
        }
    }

    // ─ MARK: FPS · CADisplayLink
    private func startDisplayLink() {
        let link = CADisplayLink(target: self, selector: #selector(onFrame(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
        lastFrameSampleTime = CACurrentMediaTime()
    }
    @objc private func onFrame(_ link: CADisplayLink) {
        frameCount += 1
        let now = link.timestamp
        if now - lastFrameSampleTime >= 1.0 {
            fps = Double(frameCount) / (now - lastFrameSampleTime)
            frameCount = 0
            lastFrameSampleTime = now
        }
    }

    // ─ MARK: Network · NWPathMonitor + CTTelephonyNetworkInfo
    private func startNetworkMonitor() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if path.usesInterfaceType(.wifi)            { self.network = .wifi }
                else if path.usesInterfaceType(.cellular)   { self.network = .cellular }
                else if path.usesInterfaceType(.wiredEthernet) { self.network = .wired }
                else { self.network = .none }
            }
        }
        monitor.start(queue: DispatchQueue.global(qos: .background))
        pathMonitor = monitor

        let info = CTTelephonyNetworkInfo()
        if let radios = info.serviceCurrentRadioAccessTechnology, let value = radios.values.first {
            cellTech = simplifiedRadioTech(value)
        }
    }
    private func simplifiedRadioTech(_ raw: String) -> String {
        if raw.contains("NR") { return "5G" }
        if raw.contains("LTE") { return "LTE" }
        if raw.contains("WCDMA") || raw.contains("HSDPA") || raw.contains("HSUPA") { return "3G" }
        if raw.contains("GPRS") || raw.contains("Edge") { return "2G" }
        return "—"
    }

    // ─ MARK: Volume · AVAudioSession
    private func startVolumeObserver() {
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(true, options: [])
        volume = Double(session.outputVolume) * 100
        session.publisher(for: \.outputVolume)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] v in self?.volume = Double(v) * 100 }
            .store(in: &cancellables)
    }
    private var cancellables = Set<AnyCancellable>()

    // ─ MARK: Motion · CMMotionManager (60Hz with low-pass filter for smooth visuals)
    private func startMotionUpdates() {
        let m = CMMotionManager()
        // Sample at 60Hz so the UI animates smoothly. The published values
        // are still pushed to @Published once per sample, but we apply a
        // simple low-pass filter to remove sensor jitter.
        m.accelerometerUpdateInterval = 1.0 / 60.0
        m.gyroUpdateInterval = 1.0 / 60.0
        let alpha: Double = 0.18 // 0..1, lower = smoother but laggier
        if m.isAccelerometerAvailable {
            m.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
                guard let self, let d = data else { return }
                self.accelX = self.accelX + alpha * (d.acceleration.x - self.accelX)
                self.accelY = self.accelY + alpha * (d.acceleration.y - self.accelY)
                self.accelZ = self.accelZ + alpha * (d.acceleration.z - self.accelZ)
            }
        }
        if m.isGyroAvailable {
            m.startGyroUpdates(to: .main) { [weak self] data, _ in
                guard let self, let d = data else { return }
                self.gyroX = self.gyroX + alpha * (d.rotationRate.x - self.gyroX)
                self.gyroY = self.gyroY + alpha * (d.rotationRate.y - self.gyroY)
                self.gyroZ = self.gyroZ + alpha * (d.rotationRate.z - self.gyroZ)
            }
        }
        motionManager = m
    }

    // ─ MARK: Altimeter · CMAltimeter (pressure + relative altitude)
    private func startAltimeter() {
        guard CMAltimeter.isRelativeAltitudeAvailable() else { return }
        let alt = CMAltimeter()
        alt.startRelativeAltitudeUpdates(to: .main) { [weak self] data, _ in
            guard let d = data else { return }
            self?.pressureHpa = d.pressure.doubleValue * 10  // kPa → hPa
            self?.altitudeM = d.relativeAltitude.doubleValue
        }
        altimeter = alt
    }

    // ─ MARK: Compass · CLLocationManager (heading)
    private func startCompass() {
        let lm = CLLocationManager()
        lm.delegate = self
        lm.requestWhenInUseAuthorization()
        lm.headingFilter = 1
        if CLLocationManager.headingAvailable() {
            lm.startUpdatingHeading()
        }
        locationManager = lm
    }

    // ─ MARK: Pedometer · CMPedometer (steps + distance)
    private func startPedometer() {
        guard CMPedometer.isStepCountingAvailable() else { return }
        let p = CMPedometer()
        let start = Calendar.current.startOfDay(for: Date())
        p.startUpdates(from: start) { [weak self] data, _ in
            guard let d = data else { return }
            DispatchQueue.main.async {
                self?.steps = d.numberOfSteps.intValue
                if let dist = d.distance {
                    self?.distanceKm = dist.doubleValue / 1000
                }
            }
        }
        pedometer = p
    }

    // ─ MARK: Proximity · UIDevice
    private func observeProximity() {
        NotificationCenter.default.publisher(for: UIDevice.proximityStateDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.proximityNear = UIDevice.current.proximityState }
            .store(in: &cancellables)
    }

    // ─ MARK: Static device info (model + chip via lookup)
    private func readStaticInfo() {
        iosVersion = UIDevice.current.systemVersion
        locale = Locale.current.identifier
        timeZone = TimeZone.current.identifier
        let bounds = UIScreen.main.nativeBounds
        displayRes = "\(Int(bounds.width)) × \(Int(bounds.height))"

        var sysinfo = utsname()
        uname(&sysinfo)
        let hwString = withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
        let info = HardwareLookup.info(for: hwString)
        deviceModel = info.model
        chip = info.chip
    }
}

// MARK: - CLLocationManagerDelegate (heading)
extension DeviceMetrics: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let h = newHeading.trueHeading > 0 ? newHeading.trueHeading : newHeading.magneticHeading
        Task { @MainActor in self.heading = h }
    }
}

// MARK: - Hardware lookup
struct HardwareLookup {
    struct Info { let model: String; let chip: String }
    static func info(for hw: String) -> Info {
        switch hw {
        case "iPhone18,1": return .init(model: "iPhone 17 Pro", chip: "A19 Pro")
        case "iPhone17,3": return .init(model: "iPhone 16", chip: "A18")
        case "iPhone17,4": return .init(model: "iPhone 16 Plus", chip: "A18")
        case "iPhone17,1": return .init(model: "iPhone 16 Pro", chip: "A18 Pro")
        case "iPhone17,2": return .init(model: "iPhone 16 Pro Max", chip: "A18 Pro")
        case "iPhone16,1": return .init(model: "iPhone 15 Pro", chip: "A17 Pro")
        case "iPhone16,2": return .init(model: "iPhone 15 Pro Max", chip: "A17 Pro")
        case "iPhone15,4": return .init(model: "iPhone 15", chip: "A16")
        case "iPhone15,5": return .init(model: "iPhone 15 Plus", chip: "A16")
        case "iPhone15,2": return .init(model: "iPhone 14 Pro", chip: "A16")
        case "iPhone15,3": return .init(model: "iPhone 14 Pro Max", chip: "A16")
        case "iPhone14,7": return .init(model: "iPhone 14", chip: "A15")
        case "iPhone14,8": return .init(model: "iPhone 14 Plus", chip: "A15")
        case "x86_64", "arm64": return .init(model: "Simulator", chip: "Host")
        default:           return .init(model: hw, chip: "—")
        }
    }
}

extension UIDevice.BatteryState {
    var label: String {
        switch self {
        case .charging:  return "CHARGING"
        case .full:      return "FULL"
        case .unplugged: return "UNPLUGGED"
        default:         return "UNKNOWN"
        }
    }
}

extension ProcessInfo.ThermalState {
    var name: String {
        switch self {
        case .nominal:  return "nominal"
        case .fair:     return "fair"
        case .serious:  return "serious"
        case .critical: return "critical"
        @unknown default: return "nominal"
        }
    }
    var friendly: String {
        switch self {
        case .nominal:  return "NORMAL"
        case .fair:     return "WARMER"
        case .serious:  return "HOT"
        case .critical: return "VERY HOT"
        @unknown default: return "NORMAL"
        }
    }
}


extension DeviceMetrics {
    /// Friendly label like "4h 12m" or "—" when we don't have data yet.
    var batteryRemainingLabel: String {
        if batteryState == .charging { return "CHARGING" }
        if batteryState == .full     { return "FULL" }
        guard let h = batteryHoursRemaining, h.isFinite, h > 0 else { return "—" }
        let hours = Int(h)
        let minutes = Int((h - Double(hours)) * 60)
        if hours == 0 { return "\(minutes)m" }
        return "\(hours)h \(minutes)m"
    }
}
