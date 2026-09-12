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

// MARK: - Apple Bento Card Surface

public struct AppleBentoCard<Content: View>: View {
    public var radius: CGFloat = ROGRadius.card
    public var padding: CGFloat = 16
    public let content: Content

    public init(radius: CGFloat = ROGRadius.card, padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.radius = radius
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(padding)
            .background(
                ZStack {
                    VisualEffectBackground(material: .contentBackground, blendingMode: .withinWindow)
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), Color.white.opacity(0.01)],
                        startPoint: .top, endPoint: .bottom
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(ROGColor.hairline, lineWidth: 0.6)
            )
            .shadow(color: .black.opacity(0.16), radius: 10, y: 5)
    }
}

// MARK: - Apple Activity-Style Telemetry Ring

public struct ActivityRing: View {
    public var progress: Double // 0.0 ... 1.0
    public var ringWidth: CGFloat
    public var gradientColors: [Color]
    public var backgroundColor: Color

    public init(
        progress: Double,
        ringWidth: CGFloat = 8,
        gradientColors: [Color],
        backgroundColor: Color = Color.secondary.opacity(0.18)
    ) {
        self.progress = min(1.0, max(0.0, progress))
        self.ringWidth = ringWidth
        self.gradientColors = gradientColors
        self.backgroundColor = backgroundColor
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(backgroundColor, lineWidth: ringWidth)

            Circle()
                .trim(from: 0.0, to: CGFloat(progress))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: gradientColors),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
    }
}

// MARK: - Apple Grouped Settings Container & Row

public struct AppleGroupedBox<Content: View>: View {
    public let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: ROGRadius.tile, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ROGRadius.tile, style: .continuous)
                .stroke(ROGColor.hairline, lineWidth: 0.6)
        )
    }
}

public struct SettingsRowView<TrailingContent: View>: View {
    let icon: String
    var iconColor: Color
    let title: String
    var subtitle: String?
    let trailing: TrailingContent

    public init(
        icon: String,
        iconColor: Color = .secondary,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> TrailingContent
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ROGType.bodyEmphasized())
                    .foregroundStyle(.primary)

                if let subtitle {
                    Text(subtitle)
                        .font(ROGType.caption())
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 16)

            trailing
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

public struct KeyCapBadge: View {
    let label: String

    public init(_ label: String) {
        self.label = label
    }

    public var body: some View {
        Text(label)
            .font(.system(size: 10.5, weight: .medium, design: .rounded))
            .foregroundStyle(.primary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3.5)
            .background(Color(NSColor.controlColor).opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: ROGRadius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ROGRadius.control, style: .continuous)
                    .stroke(ROGColor.hairline, lineWidth: 0.5)
            )
    }
}

