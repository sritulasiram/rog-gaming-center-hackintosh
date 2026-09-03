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

    private let queue = DispatchQueue(label: "com.asus.roggamingcenter.smc", qos: .utility)
    private var connection: io_connect_t = 0
    public private(set) var isAvailable: Bool = false

    private init() {
        openConnection()
    }

    deinit {
        closeConnection()
    }

    private func openConnection() {
        let mainPort: mach_port_t
        if #available(macOS 12.0, *) {
            mainPort = kIOMainPortDefault
        } else {
            mainPort = kIOMasterPortDefault
        }

        let service = IOServiceGetMatchingService(mainPort, IOServiceMatching("AppleSMC"))
        guard service != 0 else {
            isAvailable = false
            return
        }

        var conn: io_connect_t = 0
        let res = IOServiceOpen(service, mach_task_self_, 0, &conn)
        IOObjectRelease(service)

        guard res == KERN_SUCCESS else {
            isAvailable = false
            return
        }

        // Open SMC user client session (Selector 0)
        let openRes = IOConnectCallStructMethod(conn, 0, nil, 0, nil, nil)
        if openRes == KERN_SUCCESS {
            self.connection = conn
            self.isAvailable = true
        } else {
            IOServiceClose(conn)
            self.isAvailable = false
        }
    }

    private func closeConnection() {
        if connection != 0 {
            _ = IOConnectCallStructMethod(connection, 1 /* close */, nil, 0, nil, nil)
            IOServiceClose(connection)
            connection = 0
            isAvailable = false
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
            guard infoRes == KERN_SUCCESS else { return nil }

            let dataSize = outData.keyInfo_dataSize
            let dataType = outData.keyInfo_dataType
            guard dataSize > 0 && dataSize <= 32 else { return nil }

            inData.keyInfo_dataSize = dataSize
            inData.data8 = Self.SMC_CMD_READ_BYTES

            let readRes = callSMC(input: &inData, output: &outData)
            guard readRes == KERN_SUCCESS else { return nil }

            let mirror = Mirror(reflecting: outData.bytes)
            let rawBytes = mirror.children.prefix(Int(dataSize)).map { $0.value as! UInt8 }
            return (dataType: dataType, bytes: rawBytes)
        }
    }

    /// Reads real hardware temperature in Celsius (sp78 format)
    public func readTemperature(key: String) -> Double? {
        guard let info = readKey(key), info.bytes.count >= 2 else { return nil }
        // sp78: signed fixed point with 7 integer bits and 8 fractional bits
        let raw = (Int16(info.bytes[0]) << 8) | Int16(info.bytes[1])
        let temp = Double(raw) / 256.0
        // Sanity check: valid silicon temperature range
        if temp > 0 && temp < 115.0 {
            return temp
        }
        return nil
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

    /// Reads GPU temperature
    public func readGPUTemperature() -> Double? {
        let candidateKeys = ["TG0P", "TG0D", "TG0E", "TC0G"]
        for key in candidateKeys {
            if let temp = readTemperature(key: key) {
                return temp
            }
        }
        return nil
    }

    /// Reads fan RPM for specified index (0 = CPU, 1 = GPU)
    public func readFanRPM(index: Int) -> Double? {
        let key = "F\(index)Ac"
        guard let info = readKey(key), info.bytes.count >= 2 else { return nil }
        // fpe2: unsigned 14.2 fixed point
        let raw = (UInt16(info.bytes[0]) << 8) | UInt16(info.bytes[1])
        let rpm = Double(raw) / 4.0
        return rpm
    }

    /// Reads maximum fan RPM for specified index
    public func readMaxFanRPM(index: Int) -> Double? {
        let key = "F\(index)Mx"
        guard let info = readKey(key), info.bytes.count >= 2 else { return nil }
        let raw = (UInt16(info.bytes[0]) << 8) | UInt16(info.bytes[1])
        let rpm = Double(raw) / 4.0
        if rpm > 1000 {
            return rpm
        }
        return nil
    }

    /// Reads total number of physical fans managed by SMC
    public func readFanCount() -> Int {
        if let info = readKey("FNum"), !info.bytes.isEmpty {
            return Int(info.bytes[0])
        }
        return 0
    }
}
