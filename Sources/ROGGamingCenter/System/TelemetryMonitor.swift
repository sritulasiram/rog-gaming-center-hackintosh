import Foundation
import Darwin
import IOKit
import IOKit.ps
import Observation

// MARK: - Models

struct CPULoad: Equatable {
    var user: Double = 0
    var system: Double = 0
    var total: Double { min(100, user + system) }
}

struct MemoryUsage: Equatable {
    var totalGB: Double = 0
    var usedGB: Double = 0
    var compressedGB: Double = 0
    var usedFraction: Double { totalGB > 0 ? min(1, usedGB / totalGB) : 0 }
}

struct BatteryStatus: Equatable {
    var isPresent = false
    var percent = 0
    var isCharging = false
    var isOnAC = false
    var timeRemainingMinutes: Int?
    /// Only available from AppleSmartBattery, not from the IOPS fallback.
    var details: Details?

    struct Details: Equatable {
        var cycleCount: Int
        var healthPercent: Int
        var designCapacityMAh: Int
        var maxCapacityMAh: Int
        var watts: Double
        var temperatureCelsius: Double?

        var condition: String {
            healthPercent >= 80 ? "Normal" : (healthPercent >= 60 ? "Service Recommended" : "Replace Soon")
        }
    }
}

/// Values are nil when the SMC does not expose that sensor.
struct ThermalStatus: Equatable {
    var cpuCelsius: Int?
    /// One entry per fan the SMC reports a speed for; empty when it reports none.
    var fanRPMs: [Int] = []
}

struct SystemInfo: Equatable {
    var cpuName = ""
    var physicalCores = 0
    var logicalCores = 0
    var memoryGB = 0
    /// e.g. "26.7.1"
    var osVersion = ""
    /// Marketing name, e.g. "Tahoe"; empty for releases this build doesn't know.
    var osName = ""
    var osBuild = ""
    /// SMBIOS model identifier (on a Hackintosh, the one chosen in OpenCore).
    var model = ""
}

struct CPUSample: Identifiable, Equatable {
    let id: Int
    let value: Double
}

// MARK: - Monitor

/// Publishes system telemetry. Sampling only runs while at least one view is
/// observing (`beginObserving` / `endObserving`), so a hidden app costs nothing.
@MainActor
@Observable
final class TelemetryMonitor {
    private(set) var cpu = CPULoad()
    private(set) var memory = MemoryUsage()
    private(set) var battery = BatteryStatus()
    private(set) var thermal = ThermalStatus()
    private(set) var uptime: TimeInterval = 0
    private(set) var cpuHistory: [CPUSample] = []
    let info: SystemInfo
    let historyLength = 60

    @ObservationIgnored private let sampler = SystemSampler()
    @ObservationIgnored private let queue = DispatchQueue(label: "rog.telemetry", qos: .utility)
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var observers = 0
    @ObservationIgnored private var sampleIndex = 0

    init() {
        info = SystemSampler.systemInfo()
        battery = sampler.battery()
    }

    func beginObserving() {
        observers += 1
        guard observers == 1 else { return }
        sample()
        let t = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sample() }
        }
        t.tolerance = 0.5
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func endObserving() {
        observers = max(0, observers - 1)
        guard observers == 0 else { return }
        timer?.invalidate()
        timer = nil
    }

    private func sample() {
        let sampler = self.sampler
        queue.async {
            let snapshot = sampler.snapshot()
            DispatchQueue.main.async { [weak self] in
                MainActor.assumeIsolated { self?.apply(snapshot) }
            }
        }
    }

    private func apply(_ s: SystemSampler.Snapshot) {
        if let cpu = s.cpu {
            self.cpu = cpu
            sampleIndex += 1
            cpuHistory.append(CPUSample(id: sampleIndex, value: cpu.total))
            if cpuHistory.count > historyLength { cpuHistory.removeFirst(cpuHistory.count - historyLength) }
        }
        if let memory = s.memory { self.memory = memory }
        battery = s.battery
        thermal = s.thermal
        uptime = s.uptime
    }
}

// MARK: - Sampler

/// Reads the raw counters. Not thread-safe: only used from the monitor's serial queue.
final class SystemSampler: @unchecked Sendable {
    struct Snapshot {
        var cpu: CPULoad?
        var memory: MemoryUsage?
        var battery: BatteryStatus
        var thermal: ThermalStatus
        var uptime: TimeInterval
    }

    private var previousTicks: host_cpu_load_info?
    /// `mach_host_self()` hands out a new port right on every call, so take it once.
    private let host = mach_host_self()
    /// The fan count never changes at runtime; nil until the SMC has answered once.
    private var fanCount: Int?

    func snapshot() -> Snapshot {
        Snapshot(cpu: cpuLoad(), memory: memory(), battery: battery(), thermal: thermal(), uptime: uptime())
    }

    /// Wall-clock time since boot, including time asleep (unlike `systemUptime`).
    private func uptime() -> TimeInterval {
        var boot = timeval()
        var size = MemoryLayout<timeval>.size
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        guard sysctl(&mib, 2, &boot, &size, nil, 0) == 0 else { return ProcessInfo.processInfo.systemUptime }
        return Date().timeIntervalSince1970 - Double(boot.tv_sec)
    }

    static func systemInfo() -> SystemInfo {
        func sysctlString(_ name: String) -> String {
            var size = 0
            guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return "" }
            var buffer = [CChar](repeating: 0, count: size)
            sysctlbyname(name, &buffer, &size, nil, 0)
            return String(cString: buffer)
        }
        func sysctlInt(_ name: String) -> Int {
            var value: Int32 = 0
            var size = MemoryLayout<Int32>.size
            return sysctlbyname(name, &value, &size, nil, 0) == 0 ? Int(value) : 0
        }

        let rawName = sysctlString("machdep.cpu.brand_string")
        let cpuName = rawName
            .replacingOccurrences(of: "(R)", with: "")
            .replacingOccurrences(of: "(TM)", with: "")
            .replacingOccurrences(of: " CPU", with: "")
            .components(separatedBy: "@").first?
            .trimmingCharacters(in: .whitespaces) ?? rawName
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return SystemInfo(
            cpuName: cpuName,
            physicalCores: sysctlInt("hw.physicalcpu"),
            logicalCores: ProcessInfo.processInfo.activeProcessorCount,
            memoryGB: Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824),
            osVersion: "\(v.majorVersion).\(v.minorVersion)" + (v.patchVersion > 0 ? ".\(v.patchVersion)" : ""),
            osName: [14: "Sonoma", 15: "Sequoia", 26: "Tahoe"][v.majorVersion] ?? "",
            osBuild: sysctlString("kern.osversion"),
            model: sysctlString("hw.model")
        )
    }

    private func cpuLoad() -> CPULoad? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        defer { previousTicks = info }
        guard let prev = previousTicks else { return nil }

        // Wrapping subtraction: the tick counters are UInt32 and can roll over.
        let user = Double(info.cpu_ticks.0 &- prev.cpu_ticks.0)
        let system = Double(info.cpu_ticks.1 &- prev.cpu_ticks.1)
        let idle = Double(info.cpu_ticks.2 &- prev.cpu_ticks.2)
        let nice = Double(info.cpu_ticks.3 &- prev.cpu_ticks.3)
        let total = user + system + idle + nice
        guard total > 0 else { return nil }
        return CPULoad(user: (user + nice) / total * 100, system: system / total * 100)
    }

    private func memory() -> MemoryUsage? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        var pageSize: vm_size_t = 0
        host_page_size(host, &pageSize)
        let gb = Double(pageSize) / 1_073_741_824
        // Same breakdown as Activity Monitor's "Memory Used": app memory (anonymous
        // pages that can't simply be dropped) + wired + compressed.
        let app = Double(stats.internal_page_count &- stats.purgeable_count) * gb
        let wired = Double(stats.wire_count) * gb
        let compressed = Double(stats.compressor_page_count) * gb
        return MemoryUsage(
            totalGB: Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824,
            usedGB: app + wired + compressed,
            compressedGB: compressed
        )
    }

    func battery() -> BatteryStatus {
        var status = BatteryStatus()

        // Live state (charge %, AC, time remaining) from IOPS: works on every Mac.
        if let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] {
            for source in sources {
                guard let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
                      desc[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                      desc[kIOPSIsPresentKey] as? Bool ?? false else { continue }
                let current = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
                let max = desc[kIOPSMaxCapacityKey] as? Int ?? 100
                status.isPresent = true
                status.percent = max > 0 ? Int(Double(current) / Double(max) * 100) : current
                status.isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
                status.isOnAC = desc[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
                if let minutes = desc[status.isCharging ? kIOPSTimeToFullChargeKey : kIOPSTimeToEmptyKey] as? Int, minutes > 0 {
                    status.timeRemainingMinutes = minutes
                }
                break
            }
        }
        guard status.isPresent else { return status }

        // Health details from AppleSmartBattery, when the battery driver provides them.
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return status }
        defer { IOObjectRelease(service) }
        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = props?.takeRetainedValue() as? [String: Any] else { return status }

        let maxCap = dict["AppleRawMaxCapacity"] as? Int ?? dict["MaxCapacity"] as? Int ?? 0
        let design = dict["DesignCapacity"] as? Int ?? 0
        // On Apple batteries MaxCapacity is a percentage; only trust mAh-sized values.
        guard maxCap > 100, design > 100 else { return status }

        let volts = Double(dict["Voltage"] as? Int ?? 0) / 1000
        let amps = Double(dict["InstantAmperage"] as? Int ?? dict["Amperage"] as? Int ?? 0) / 1000
        let tempRaw = Double(dict["Temperature"] as? Int ?? 0) / 100
        status.details = .init(
            cycleCount: dict["CycleCount"] as? Int ?? 0,
            healthPercent: Swift.max(1, Swift.min(100, Int(Double(maxCap) / Double(design) * 100))),
            designCapacityMAh: design,
            maxCapacityMAh: maxCap,
            watts: abs(volts * amps),
            temperatureCelsius: (1..<100).contains(tempRaw) ? tempRaw : nil
        )
        return status
    }

    private func thermal() -> ThermalStatus {
        let smc = SMCReader.shared
        if fanCount == nil, smc.isAvailable { fanCount = smc.readFanCount() }
        // Some kexts publish F0Ac without FNum, so always probe at least the first fan.
        let fans = (0..<max(1, fanCount ?? 0)).compactMap { smc.readFanRPM(index: $0).map { Int($0.rounded()) } }
        return ThermalStatus(
            cpuCelsius: smc.readCPUTemperature().map { Int($0.rounded()) },
            fanRPMs: fans
        )
    }
}
