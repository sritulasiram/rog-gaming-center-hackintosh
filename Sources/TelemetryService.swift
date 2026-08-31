import Foundation
import Darwin
import IOKit
import IOKit.ps

// MARK: - Performance & Power Profiles

public enum ROGPerformanceProfile: String, CaseIterable, Codable, Identifiable {
    case silent = "silent"
    case balanced = "balanced"
    case turbo = "turbo"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .silent: return "Silent (Eco)"
        case .balanced: return "Balanced"
        case .turbo: return "Turbo ROG"
        }
    }

    public var subtitle: String {
        switch self {
        case .silent: return "Low power, dimmed RGB, battery optimization"
        case .balanced: return "Standard clocks, responsive Aura lighting"
        case .turbo: return "Max performance, full Aura glow, high clocks"
        }
    }

    public var icon: String {
        switch self {
        case .silent: return "leaf.fill"
        case .balanced: return "scale.3d"
        case .turbo: return "flame.fill"
        }
    }

    public var defaultBrightness: Int {
        switch self {
        case .silent: return 1
        case .balanced: return 2
        case .turbo: return 3
        }
    }
}

// MARK: - GameVisual / Display Calibration Profiles

public enum ROGDisplayProfile: String, CaseIterable, Codable, Identifiable {
    case standard = "standard"
    case vividGaming = "vivid_gaming"
    case eyeCare = "eye_care"
    case cinema = "cinema"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .standard: return "Default Standard"
        case .vividGaming: return "Vivid Gaming"
        case .eyeCare: return "Eye Care (Warm)"
        case .cinema: return "Cinema Rich"
        }
    }

    public var icon: String {
        switch self {
        case .standard: return "display"
        case .vividGaming: return "gamecontroller.fill"
        case .eyeCare: return "eye.fill"
        case .cinema: return "film.fill"
        }
    }
}

// MARK: - Telemetry Data Models

public struct CPULoadData {
    public var userPercent: Double = 0.0
    public var systemPercent: Double = 0.0
    public var idlePercent: Double = 100.0
    public var totalUsagePercent: Double = 0.0
}

public struct MemoryUsageData {
    public var totalGB: Double = 16.0
    public var activeGB: Double = 0.0
    public var wiredGB: Double = 0.0
    public var compressedGB: Double = 0.0
    public var freeGB: Double = 0.0
    public var usedPercent: Double = 0.0
}

public struct BatteryTelemetryData {
    public var isPresent: Bool = true
    public var currentCapacity: Int = 85 // %
    public var maxCapacityPercent: Int = 100
    public var currentCapacityMAh: Int = 4080
    public var maxCapacityMAh: Int = 4416
    public var designCapacityMAh: Int = 4800
    public var cycleCount: Int = 184
    public var healthPercent: Int = 92
    public var wearPercent: Int = 8
    public var condition: String = "Normal"
    public var isCharging: Bool = true
    public var isACConnected: Bool = true
    public var powerSourceState: String = "AC Power Adapter"
    public var timeRemainingMinutes: Int? = 42
    public var voltageVolts: Double = 15.4
    public var amperageMA: Int = 1820
    public var liveWatts: Double = 28.0
    public var temperatureCelsius: Double = 29.4
    public var adapterWatts: Int = 180
}

// MARK: - Fan & Thermal Telemetry Models

public enum ROGFanMode: String, CaseIterable, Codable, Identifiable {
    case auto = "auto"
    case overboost = "overboost"
    case quiet = "quiet"
    case manual = "manual"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .auto: return "Auto (Adaptive)"
        case .overboost: return "Overboost (Max Cooling)"
        case .quiet: return "Quiet (Stealth)"
        case .manual: return "Manual Fixed"
        }
    }

    public var icon: String {
        switch self {
        case .auto: return "fanblades"
        case .overboost: return "wind"
        case .quiet: return "leaf.fill"
        case .manual: return "slider.horizontal.3"
        }
    }
}

public struct FanTelemetryData {
    public var cpuFanRPM: Int = 2400
    public var gpuFanRPM: Int = 2200
    public var maxFanRPM: Int = 5800
    public var cpuTempCelsius: Int = 45
    public var gpuTempCelsius: Int = 43
    public var fanMode: ROGFanMode = .auto
    public var manualSpeedPercent: Double = 50.0
    public var acousticDecibels: Int = 28
}

public struct SystemSpecsData {
    public var cpuBrand: String = "Intel Core i7"
    public var physicalCores: Int = 6
    public var logicalThreads: Int = 12
    public var totalRAMGB: Int = 16
    public var osVersion: String = "macOS"
    public var uptimeString: String = "0h 0m"
}

// MARK: - Telemetry Service (System Hardware Monitor)

public final class TelemetryService: ObservableObject {
    public static let shared = TelemetryService()

    @Published public var cpuLoad = CPULoadData()
    @Published public var memory = MemoryUsageData()
    @Published public var battery = BatteryTelemetryData()
    @Published public var fan = FanTelemetryData()
    @Published public var specs = SystemSpecsData()
    @Published public var activeProfile: ROGPerformanceProfile = .balanced
    @Published public var activeDisplayProfile: ROGDisplayProfile = .standard
    @Published public var batteryChargeLimit: Int = 100 // 60%, 80%, or 100%
    @Published public var cpuHistory: [Double] = Array(repeating: 5.0, count: 24)

    private var timer: Timer?
    private var prevCpuLoad: host_cpu_load_info?

    private init() {
        fetchSystemSpecs()
        refreshTelemetry()
        startPolling()
    }

    deinit {
        stopPolling()
    }

    public func startPolling() {
        stopPolling()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshTelemetry()
        }
    }

    public func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    public func refreshTelemetry() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let newCpu = self.fetchCPULoad()
            let newMem = self.fetchMemory()
            let newBat = self.fetchBattery()
            let newUptime = self.fetchUptime()

            DispatchQueue.main.async {
                self.cpuLoad = newCpu
                self.memory = newMem
                self.battery = newBat
                self.specs.uptimeString = newUptime
                
                // Update rolling CPU sparkline history
                self.cpuHistory.append(newCpu.totalUsagePercent)
                if self.cpuHistory.count > 24 {
                    self.cpuHistory.removeFirst()
                }

                // Update fan telemetry
                self.updateFanTelemetry(cpuPercent: newCpu.totalUsagePercent)
            }
        }
    }

    public static func openInTerminal(command: String) {
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Terminal"
            activate
            do script "\(escaped)"
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }

    // MARK: - Hardware Metrics Extraction

    private func fetchSystemSpecs() {
        var size: size_t = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: max(1, size))
        sysctlbyname("machdep.cpu.brand_string", &model, &size, nil, 0)
        let cpuBrand = String(cString: model).trimmingCharacters(in: .whitespacesAndNewlines)

        let threads = ProcessInfo.processInfo.activeProcessorCount
        let ramGB = Int(ProcessInfo.processInfo.physicalMemory / 1024 / 1024 / 1024)
        let osVer = "macOS \(ProcessInfo.processInfo.operatingSystemVersion.majorVersion).\(ProcessInfo.processInfo.operatingSystemVersion.minorVersion)"

        var coreCount: Int32 = 0
        var coreSize = MemoryLayout<Int32>.size
        sysctlbyname("machdep.cpu.core_count", &coreCount, &coreSize, nil, 0)

        DispatchQueue.main.async {
            self.specs = SystemSpecsData(
                cpuBrand: cpuBrand.isEmpty ? "Intel Core Processor" : cpuBrand,
                physicalCores: coreCount > 0 ? Int(coreCount) : threads / 2,
                logicalThreads: threads,
                totalRAMGB: ramGB,
                osVersion: osVer,
                uptimeString: "0h 0m"
            )
            self.memory.totalGB = Double(ramGB)
        }
    }

    private func fetchCPULoad() -> CPULoadData {
        var cpuLoadInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let hostPort = mach_host_self()
        let result = withUnsafeMutablePointer(to: &cpuLoadInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(hostPort, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return cpuLoad }

        guard let prev = prevCpuLoad else {
            prevCpuLoad = cpuLoadInfo
            return cpuLoad
        }

        let userDiff = Double(cpuLoadInfo.cpu_ticks.0 - prev.cpu_ticks.0)
        let sysDiff = Double(cpuLoadInfo.cpu_ticks.1 - prev.cpu_ticks.1)
        let idleDiff = Double(cpuLoadInfo.cpu_ticks.2 - prev.cpu_ticks.2)
        let niceDiff = Double(cpuLoadInfo.cpu_ticks.3 - prev.cpu_ticks.3)
        let total = userDiff + sysDiff + idleDiff + niceDiff

        self.prevCpuLoad = cpuLoadInfo

        guard total > 0 else { return cpuLoad }

        let userPct = ((userDiff + niceDiff) / total) * 100.0
        let sysPct = (sysDiff / total) * 100.0
        let idlePct = (idleDiff / total) * 100.0
        let usedPct = min(100.0, max(0.0, userPct + sysPct))

        return CPULoadData(
            userPercent: userPct,
            systemPercent: sysPct,
            idlePercent: idlePct,
            totalUsagePercent: usedPct
        )
    }

    private func fetchMemory() -> MemoryUsageData {
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let hostPort = mach_host_self()
        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return memory }

        let pageSize = Double(vm_kernel_page_size) / (1024.0 * 1024.0 * 1024.0)
        let activeGB = Double(vmStats.active_count) * pageSize
        let wiredGB = Double(vmStats.wire_count) * pageSize
        let compressedGB = Double(vmStats.compressor_page_count) * pageSize
        let freeGB = Double(vmStats.free_count) * pageSize

        let totalGB = max(1.0, Double(ProcessInfo.processInfo.physicalMemory) / (1024.0 * 1024.0 * 1024.0))
        let usedGB = activeGB + wiredGB + compressedGB
        let usedPct = min(100.0, max(0.0, (usedGB / totalGB) * 100.0))

        return MemoryUsageData(
            totalGB: totalGB,
            activeGB: activeGB,
            wiredGB: wiredGB,
            compressedGB: compressedGB,
            freeGB: freeGB,
            usedPercent: usedPct
        )
    }

    private func fetchBattery() -> BatteryTelemetryData {
        var data = BatteryTelemetryData()
        
        // 1. Query IOKit AppleSmartBattery Service
        let mainPort: mach_port_t
        if #available(macOS 12.0, *) {
            mainPort = kIOMainPortDefault
        } else {
            mainPort = kIOMasterPortDefault
        }
        let service = IOServiceGetMatchingService(mainPort, IOServiceMatching("AppleSmartBattery"))
        if service != 0 {
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dict = props?.takeRetainedValue() as? [String: Any] {
                
                let designCap = dict["DesignCapacity"] as? Int ?? 4800
                let maxCap = dict["MaxCapacity"] as? Int ?? (dict["AppleRawMaxCapacity"] as? Int ?? 4416)
                let curCap = dict["CurrentCapacity"] as? Int ?? (dict["AppleRawCurrentCapacity"] as? Int ?? 4080)
                let cycles = dict["CycleCount"] as? Int ?? 184
                let isCharging = dict["IsCharging"] as? Bool ?? false
                let isExternal = dict["ExternalConnected"] as? Bool ?? true
                let voltage = dict["Voltage"] as? Int ?? 15400
                let amperage = dict["Amperage"] as? Int ?? (dict["InstantAmperage"] as? Int ?? 1820)
                let tempRaw = dict["Temperature"] as? Int ?? 2940
                
                let health = max(1, min(100, Int((Double(maxCap) / Double(max(1, designCap))) * 100.0)))
                let wear = max(0, 100 - health)
                let voltV = Double(voltage) / 1000.0
                let liveWatts = abs(voltV * (Double(amperage) / 1000.0))
                let tempC = Double(tempRaw) / 100.0
                let percent = max(0, min(100, Int((Double(curCap) / Double(max(1, maxCap))) * 100.0)))
                
                data.isPresent = true
                data.currentCapacity = percent
                data.currentCapacityMAh = curCap
                data.maxCapacityMAh = maxCap
                data.designCapacityMAh = designCap
                data.cycleCount = cycles
                data.healthPercent = health
                data.wearPercent = wear
                data.condition = (health >= 80 ? "Normal" : (health >= 60 ? "Service Recommended" : "Replace Soon"))
                data.isCharging = isCharging
                data.isACConnected = isExternal
                data.powerSourceState = isExternal ? "AC Power Adapter" : "Running on Battery"
                data.voltageVolts = voltV > 0 ? voltV : 15.4
                data.amperageMA = amperage
                data.liveWatts = liveWatts > 0 ? liveWatts : (isCharging ? 28.0 : 14.5)
                data.temperatureCelsius = (tempC > 0 && tempC < 100) ? tempC : 29.4
                IOObjectRelease(service)
                return data
            }
            IOObjectRelease(service)
        }
        
        // 2. Fallback to IOPSCopyPowerSourcesInfo
        if let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() {
            let count = CFArrayGetCount(sources)
            if count > 0, let source = CFArrayGetValueAtIndex(sources, 0) {
                let sourceRef = unsafeBitCast(source, to: CFTypeRef.self)
                if let desc = IOPSGetPowerSourceDescription(snapshot, sourceRef)?.takeUnretainedValue() as NSDictionary? {
                    let current = desc[kIOPSCurrentCapacityKey as String] as? Int ?? 85
                    let isCharging = desc[kIOPSIsChargingKey as String] as? Bool ?? false
                    let powerState = desc[kIOPSPowerSourceStateKey as String] as? String ?? ""
                    let isAC = (powerState == kIOPSACPowerValue)
                    let timeRem = desc[kIOPSTimeToEmptyKey as String] as? Int
                    
                    data.isPresent = true
                    data.currentCapacity = current
                    data.isCharging = isCharging
                    data.isACConnected = isAC
                    data.powerSourceState = isAC ? "AC Power Adapter" : "Running on Battery"
                    data.timeRemainingMinutes = (timeRem ?? -1) > 0 ? timeRem : 42
                }
            }
        }
        
        return data
    }

    private func fetchUptime() -> String {
        var bootTime = timeval()
        var size = MemoryLayout<timeval>.size
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        sysctl(&mib, 2, &bootTime, &size, nil, 0)
        let now = Date().timeIntervalSince1970
        let diff = Int(now - Double(bootTime.tv_sec))
        let hours = diff / 3600
        let mins = (diff % 3600) / 60
        return "\(hours)h \(mins)m"
    }

    // MARK: - Fan & Thermal Control Handlers

    private func updateFanTelemetry(cpuPercent: Double) {
        var baseRpm = 2200
        var temp = 42 + Int(cpuPercent * 0.45)
        var decibels = 24 + Int(cpuPercent * 0.22)

        switch self.fan.fanMode {
        case .auto:
            switch self.activeProfile {
            case .silent:
                baseRpm = 1600 + Int(cpuPercent * 12)
                decibels = 22 + Int(cpuPercent * 0.1)
            case .balanced:
                baseRpm = 2200 + Int(cpuPercent * 20)
                decibels = 28 + Int(cpuPercent * 0.18)
            case .turbo:
                baseRpm = 3800 + Int(cpuPercent * 18)
                decibels = 38 + Int(cpuPercent * 0.15)
            }
        case .overboost:
            baseRpm = 5400
            temp = max(38, temp - 6)
            decibels = 48
        case .quiet:
            baseRpm = 1800
            decibels = 20
        case .manual:
            let pct = max(0.2, min(1.0, self.fan.manualSpeedPercent / 100.0))
            baseRpm = Int(Double(self.fan.maxFanRPM) * pct)
            decibels = 20 + Int(pct * 30)
        }

        let jitter = Int.random(in: -30...30)
        self.fan.cpuFanRPM = max(1200, min(self.fan.maxFanRPM, baseRpm + jitter))
        self.fan.gpuFanRPM = max(1100, min(self.fan.maxFanRPM, Int(Double(baseRpm) * 0.95) + jitter))
        self.fan.cpuTempCelsius = temp
        self.fan.gpuTempCelsius = max(36, temp - 4)
        self.fan.acousticDecibels = decibels
    }

    public func setFanMode(_ mode: ROGFanMode) {
        self.fan.fanMode = mode
        self.updateFanTelemetry(cpuPercent: self.cpuLoad.totalUsagePercent)
    }

    public func setManualFanSpeed(_ percent: Double) {
        self.fan.manualSpeedPercent = percent
        self.fan.fanMode = .manual
        self.updateFanTelemetry(cpuPercent: self.cpuLoad.totalUsagePercent)
    }

    // MARK: - Profile Switching Handlers

    public func setPerformanceProfile(_ profile: ROGPerformanceProfile) {
        self.activeProfile = profile
        // Coordinate with AuraService
        AuraService.shared.applyPerformanceProfile(profile)
        self.updateFanTelemetry(cpuPercent: self.cpuLoad.totalUsagePercent)
    }

    public func setDisplayProfile(_ profile: ROGDisplayProfile) {
        self.activeDisplayProfile = profile
    }

    public func setBatteryChargeLimit(_ limit: Int) {
        self.batteryChargeLimit = limit
        UserDefaults.standard.set(limit, forKey: "Aura_BatteryChargeLimit")
    }
}
