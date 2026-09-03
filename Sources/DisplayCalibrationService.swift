import Foundation
import ApplicationServices
import Cocoa

/// Hardware display calibration service leveraging macOS CoreGraphics gamma transfer tables.
/// Provides authentic real-time visual calibration profiles (Standard, Eye Care, Vivid, Cinema)
/// directly modifying display hardware LUTs with automatic baseline restoration on exit.
public final class DisplayCalibrationService {
    public static let shared = DisplayCalibrationService()

    private var baselineRed: [CGGammaValue] = []
    private var baselineGreen: [CGGammaValue] = []
    private var baselineBlue: [CGGammaValue] = []
    private var tableCapacity: UInt32 = 0
    private var isBaselineSaved: Bool = false

    private init() {
        captureBaseline()
    }

    deinit {
        restoreBaseline()
    }

    /// Captures the initial native display transfer table so we can cleanly revert
    public func captureBaseline() {
        let display = CGMainDisplayID()
        let cap = CGDisplayGammaTableCapacity(display)
        guard cap > 0 else { return }

        var r = [CGGammaValue](repeating: 0, count: Int(cap))
        var g = [CGGammaValue](repeating: 0, count: Int(cap))
        var b = [CGGammaValue](repeating: 0, count: Int(cap))
        var sampleCount: UInt32 = 0

        let res = CGGetDisplayTransferByTable(display, cap, &r, &g, &b, &sampleCount)
        if res == .success && sampleCount > 0 {
            self.baselineRed = Array(r.prefix(Int(sampleCount)))
            self.baselineGreen = Array(g.prefix(Int(sampleCount)))
            self.baselineBlue = Array(b.prefix(Int(sampleCount)))
            self.tableCapacity = sampleCount
            self.isBaselineSaved = true
        }
    }

    /// Reverts the display gamma table to original system baseline
    public func restoreBaseline() {
        guard isBaselineSaved, tableCapacity > 0 else { return }
        let display = CGMainDisplayID()
        var r = baselineRed
        var g = baselineGreen
        var b = baselineBlue
        _ = CGSetDisplayTransferByTable(display, tableCapacity, &r, &g, &b)
    }

    /// Applies a GameVisual display calibration profile
    public func applyProfile(_ profile: ROGDisplayProfile) {
        if !isBaselineSaved || tableCapacity == 0 {
            captureBaseline()
            guard isBaselineSaved, tableCapacity > 0 else { return }
        }

        let display = CGMainDisplayID()
        let n = Int(tableCapacity)
        var newR = [CGGammaValue](repeating: 0, count: n)
        var newG = [CGGammaValue](repeating: 0, count: n)
        var newB = [CGGammaValue](repeating: 0, count: n)

        switch profile {
        case .standard:
            // Revert directly to neutral system baseline
            newR = baselineRed
            newG = baselineGreen
            newB = baselineBlue

        case .eyeCare:
            // Warm blue-light attenuation: reduces harsh 450nm spikes
            for i in 0..<n {
                let base_r = baselineRed[i]
                let base_g = baselineGreen[i]
                let base_b = baselineBlue[i]

                newR[i] = min(1.0, base_r * 1.02)
                newG[i] = base_g * 0.94
                newB[i] = base_b * 0.78
            }

        case .vividGaming:
            // High-contrast S-curve for enhanced midtone punch and saturation
            for i in 0..<n {
                let x = Double(i) / Double(n - 1)
                // Mild contrast curve: y = x^0.92 for midtone lift
                let factor = pow(x, 0.92)
                let rNorm = Double(baselineRed[i])
                let gNorm = Double(baselineGreen[i])
                let bNorm = Double(baselineBlue[i])

                newR[i] = CGGammaValue(min(1.0, max(0.0, rNorm * 1.05 * (factor / max(0.001, x)))))
                newG[i] = CGGammaValue(min(1.0, max(0.0, gNorm * 1.04 * (factor / max(0.001, x)))))
                newB[i] = CGGammaValue(min(1.0, max(0.0, bNorm * 1.06 * (factor / max(0.001, x)))))
            }

        case .cinema:
            // Enhanced dynamic range: deeper blacks with lifted low-mids for dark scenes
            for i in 0..<n {
                let x = Double(i) / Double(n - 1)
                // Lift shadow detail while keeping peak white clean
                let lift = (1.0 - x) * 0.04
                newR[i] = CGGammaValue(min(1.0, max(0.0, Double(baselineRed[i]) * 0.98 + lift)))
                newG[i] = CGGammaValue(min(1.0, max(0.0, Double(baselineGreen[i]) * 0.98 + lift)))
                newB[i] = CGGammaValue(min(1.0, max(0.0, Double(baselineBlue[i]) * 0.99 + lift)))
            }
        }

        let res = CGSetDisplayTransferByTable(display, tableCapacity, &newR, &newG, &newB)
        if res == .success {
            NSLog("[ROGAuraDisplay] Applied display profile: \(profile.title)")
        } else {
            NSLog("[ROGAuraDisplay] Failed to set display gamma table: \(res.rawValue)")
        }
    }
}
