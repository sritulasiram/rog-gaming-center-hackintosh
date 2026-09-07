import SwiftUI
import AppKit

// MARK: - ROG × Apple Design System
//
// Rules of thumb applied everywhere in this file and meant to be reused
// across every screen:
//  1. Text is normal-case, system font, `.primary` / `.secondary` first.
//     ALL CAPS and monospaced fonts are used ONLY for literal live
//     numeric telemetry (temps, %, MHz, RPM) — never for labels or nav.
//  2. Corners are continuous ("squircle") and come from a fixed scale,
//     never an arbitrary number.
//  3. Surfaces are real layered glass (material + soft top highlight +
//     hairline stroke + gentle shadow), not a flat color at low opacity.
//  4. The ROG red is a single, restrained accent — used for the
//     selection state, the logo, and rare emphasis. It never floods a
//     whole card.

// MARK: - Corner Radius Scale

public enum ROGRadius {
    public static let control: CGFloat = 8      // small controls, chips
    public static let tile: CGFloat = 14         // inner tiles, rows
    public static let card: CGFloat = 20         // primary glass cards
    public static let sheet: CGFloat = 28         // full panels / popovers
}

// MARK: - Color Tokens

public enum ROGColor {
    /// The single ROG accent — used sparingly (selection, key actions, logo).
    public static let accent = Color(red: 0.92, green: 0.16, blue: 0.20)
    public static let accentSoft = accent.opacity(0.14)

    // Status colors kept close to Apple's own semantic palette rather than
    // saturated primaries.
    public static let good = Color(red: 0.20, green: 0.78, blue: 0.35)
    public static let warn = Color(red: 0.98, green: 0.62, blue: 0.05)
    public static let bad = Color(red: 0.94, green: 0.27, blue: 0.27)
    public static let info = Color(red: 0.02, green: 0.52, blue: 1.0)

    public static let hairline = Color(NSColor.separatorColor).opacity(0.5)
}

// MARK: - Typography
//
// Every text role in the app should come from here. `.rounded` is used
// for large numeric hero values (matches Apple's own dashboards/widgets);
// everything else is the default SF Pro grade.

public enum ROGType {
    public static func title() -> Font { .system(size: 22, weight: .semibold) }
    public static func sectionHeader() -> Font { .system(size: 13, weight: .semibold) }
    public static func body() -> Font { .system(size: 12, weight: .regular) }
    public static func bodyEmphasized() -> Font { .system(size: 12, weight: .medium) }
    public static func caption() -> Font { .system(size: 11, weight: .regular) }
    public static func footnote() -> Font { .system(size: 10, weight: .medium) }

    /// Large hero numeric readout (e.g. die temp, CPU load).
    public static func heroNumber() -> Font { .system(size: 34, weight: .semibold, design: .rounded) }
    /// Small inline numeric readout — monospacedDigit so values don't jitter,
    /// but still the regular font grade, not a full monospace typeface.
    public static func inlineNumber() -> Font { .system(size: 12, weight: .semibold, design: .rounded) }
}

// MARK: - Glass Surface

/// A real layered "Liquid Glass" surface: NSVisualEffectView material,
/// a faint top highlight to catch light, a hairline border, and a soft
/// shadow — instead of a flat, low-opacity color fill.
public struct GlassSurface: ViewModifier {
    public var radius: CGFloat = ROGRadius.card
    public var material: NSVisualEffectView.Material = .contentBackground
    public var padding: CGFloat = 16

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                ZStack {
                    VisualEffectBackground(material: material, blendingMode: .withinWindow)
                    LinearGradient(
                        colors: [Color.white.opacity(0.10), Color.white.opacity(0.0)],
                        startPoint: .top, endPoint: .bottom
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(ROGColor.hairline, lineWidth: 0.75)
            )
            .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
    }
}

public extension View {
    /// Apply the standard glass-card treatment used across the app.
    func glassCard(radius: CGFloat = ROGRadius.card, padding: CGFloat = 16) -> some View {
        modifier(GlassSurface(radius: radius, padding: padding))
    }
}

// MARK: - Section Header

/// Normal-case section header, Apple style — replaces the old bold
/// monospaced ALL CAPS labels used across the app.
public struct SectionLabel: View {
    let title: String
    let systemImage: String?

    public init(_ title: String, systemImage: String? = nil) {
        self.title = title
        self.systemImage = systemImage
    }

    public var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Text(title)
                .font(ROGType.sectionHeader())
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Accent Badge (Capsule)

/// Small tag/badge — capsule shaped, tinted with the accent instead of a
/// hard-edged, tiny, monospaced chip.
public struct AccentBadge: View {
    let text: String
    var color: Color = ROGColor.accent

    public init(_ text: String, color: Color = ROGColor.accent) {
        self.text = text
        self.color = color
    }

    public var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.14)))
    }
}

// MARK: - Labeled Row (for spec / key-value lists)

public struct LabeledRow: View {
    let title: String
    let value: String

    public init(_ title: String, _ value: String) {
        self.title = title
        self.value = value
    }

    public var body: some View {
        HStack {
            Text(title)
                .font(ROGType.body())
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(ROGType.inlineNumber())
                .foregroundStyle(.primary)
                .monospacedDigit()
        }
    }
}
