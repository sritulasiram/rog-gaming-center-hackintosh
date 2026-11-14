import Foundation
import IOKit

/// Native Swift IOKit interface for AppleSMC / VirtualSMC on macOS & Hackintosh.
/// Provides direct hardware readouts for CPU/GPU temperatures and cooling fan speeds
/// with zero external C bridging headers or third-party dependencies.
public final class SMCReader {
    public static let shared = SMCReader()

    // 80-byte memory layout matching AppleSMC kernel SMCKeyData_t
    public struct SMCKeyData {
        public var key: UInt32 = 0
        // vers: 6 bytes + 2 bytes padding = 8 bytes
        public var vers_major: UInt8 = 0
        public var vers_minor: UInt8 = 0
        public var vers_build: UInt8 = 0
        public var vers_reserved: UInt8 = 0
        public var vers_release: UInt16 = 0
        public var _pad0: UInt16 = 0
        // pLimitData: 16 bytes
        public var pLimit_version: UInt16 = 0
        public var pLimit_length: UInt16 = 0
        public var pLimit_cpuPLimit: UInt32 = 0
        public var pLimit_gpuPLimit: UInt32 = 0
        public var pLimit_memPLimit: UInt32 = 0
        // keyInfo: 12 bytes
        public var keyInfo_dataSize: UInt32 = 0
        public var keyInfo_dataType: UInt32 = 0
        public var keyInfo_dataAttributes: UInt8 = 0
        public var _pad1: (UInt8, UInt8, UInt8) = (0, 0, 0)
        // result, status, data8: 3 bytes + 1 byte padding = 4 bytes
        public var result: UInt8 = 0
        public var status: UInt8 = 0
        public var data8: UInt8 = 0
        public var _pad2: UInt8 = 0
        // data32: 4 bytes
        public var data32: UInt32 = 0
        // bytes: 32 bytes
        public var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                           UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                           UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                           UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) =
            (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)

        public init() {}
    }

    private static let KERNEL_INDEX_SMC: UInt32 = 2
    private static let SMC_CMD_READ_KEYINFO: UInt8 = 9
    private static let SMC_CMD_READ_BYTES: UInt8 = 5

    private let queue = DispatchQueue(label: "rog.smc", qos: .utility)
    private var connection: io_connect_t = 0
    private var lastConnectionAttempt: Date = .distantPast
    private let connectionRetryInterval: TimeInterval = 30.0

    /// Whether an SMC connection is currently open. Safe to read from any thread.
    public var isAvailable: Bool { queue.sync { connection != 0 } }

    private init() {
        openConnection()
    }

    deinit {
        closeConnection()
    }

    /// Only called from `init` or on `queue`.
    private func openConnection() {
        let now = Date()
        guard now.timeIntervalSince(lastConnectionAttempt) >= connectionRetryInterval else { return }
        lastConnectionAttempt = now

        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return }

        var conn: io_connect_t = 0
        let res = IOServiceOpen(service, mach_task_self_, 0, &conn)
        IOObjectRelease(service)
        guard res == KERN_SUCCESS else { return }

        // Open SMC user client session (Selector 0)
        if IOConnectCallStructMethod(conn, 0, nil, 0, nil, nil) == KERN_SUCCESS {
            connection = conn
        } else {
            IOServiceClose(conn)
        }
    }

    private func closeConnection() {
        if connection != 0 {
            _ = IOConnectCallStructMethod(connection, 1 /* close */, nil, 0, nil, nil)
            IOServiceClose(connection)
            connection = 0
        }
    }

    public static func fourCharCode(from str: String) -> UInt32 {
        var res: UInt32 = 0
        for ch in str.utf8.prefix(4) {
            res = (res << 8) | UInt32(ch)
        }
        return res
    }

    private func callSMC(input: inout SMCKeyData, output: inout SMCKeyData) -> kern_return_t {
        guard connection != 0 else { return kIOReturnNotOpen }
        let size = MemoryLayout<SMCKeyData>.size
        var outSize = size
        return IOConnectCallStructMethod(connection, Self.KERNEL_INDEX_SMC, &input, size, &output, &outSize)
    }

    /// Reads a key value from AppleSMC
    public func readKey(_ keyStr: String) -> (dataType: UInt32, bytes: [UInt8])? {
        return queue.sync { () -> (dataType: UInt32, bytes: [UInt8])? in
            if connection == 0 {
                openConnection()
                guard connection != 0 else { return nil }
            }

            var inData = SMCKeyData()
            var outData = SMCKeyData()
            inData.key = Self.fourCharCode(from: keyStr)
            inData.data8 = Self.SMC_CMD_READ_KEYINFO

            let infoRes = callSMC(input: &inData, output: &outData)
            guard infoRes == KERN_SUCCESS, outData.result == 0 else { return nil }

            let dataSize = outData.keyInfo_dataSize
            let dataType = outData.keyInfo_dataType
            guard dataSize > 0 && dataSize <= 32 else { return nil }

            inData.keyInfo_dataSize = dataSize
            inData.data8 = Self.SMC_CMD_READ_BYTES

            let readRes = callSMC(input: &inData, output: &outData)
            guard readRes == KERN_SUCCESS, outData.result == 0 else { return nil }

            let rawBytes = withUnsafeBytes(of: outData.bytes) { Array($0.prefix(Int(dataSize))) }
            return (dataType: dataType, bytes: rawBytes)
        }
    }

    /// Decodes a numeric SMC value according to its declared type. The same key is
    /// published in different formats depending on the SMC generation (e.g. fan speed
    /// is `fpe2` on older models and `flt ` on newer ones), so the type must be honored.
    static func decodeNumber(dataType: UInt32, bytes: [UInt8]) -> Double? {
        func bigEndian16() -> UInt16? {
            bytes.count >= 2 ? (UInt16(bytes[0]) << 8) | UInt16(bytes[1]) : nil
        }
        switch dataType {
        case fourCharCode(from: "sp78"): // signed 7.8 fixed point
            return bigEndian16().map { Double(Int16(bitPattern: $0)) / 256 }
        case fourCharCode(from: "fpe2"): // unsigned 14.2 fixed point
            return bigEndian16().map { Double($0) / 4 }
        case fourCharCode(from: "flt "): // little-endian IEEE float
            guard bytes.count >= 4 else { return nil }
            let bits = UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
            let value = Double(Float(bitPattern: bits))
            return value.isFinite ? value : nil
        case fourCharCode(from: "ui8 "):
            return bytes.first.map(Double.init)
        case fourCharCode(from: "ui16"):
            return bigEndian16().map(Double.init)
        default:
            return nil
        }
    }

    private func readNumber(_ key: String) -> Double? {
        readKey(key).flatMap { Self.decodeNumber(dataType: $0.dataType, bytes: $0.bytes) }
    }

    /// Reads a temperature in Celsius, rejecting values outside the plausible silicon range.
    public func readTemperature(key: String) -> Double? {
        guard let temp = readNumber(key), temp > 0, temp < 115 else { return nil }
        return temp
    }

    /// Reads primary CPU temperature across standard Intel/Apple sensors
    public func readCPUTemperature() -> Double? {
        // Priority list of common CPU sensor keys
        let candidateKeys = [
            "TC0P", // CPU Proximity
            "TC0D", // CPU Die
            "TC0E", "TC0F",
            "TC1C", "TC2C", "TC3C", "TC4C", // Core temps
            "TCXC"
        ]
        for key in candidateKeys {
            if let temp = readTemperature(key: key) {
                return temp
            }
        }
        return nil
    }

    /// Current speed of fan `index` in RPM, or nil when the SMC doesn't publish it.
    public func readFanRPM(index: Int) -> Double? {
        guard let rpm = readNumber("F\(index)Ac"), rpm >= 0, rpm < 20_000 else { return nil }
        return rpm
    }

    /// Number of fans the SMC reports (0 when it publishes none).
    public func readFanCount() -> Int {
        readNumber("FNum").map { max(0, min(8, Int($0))) } ?? 0
    }
}
