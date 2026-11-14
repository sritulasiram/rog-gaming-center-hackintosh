import SwiftUI
import AuraCore

/// Simplified laptop keyboard lit by the four hardware zones. Animates only for
/// animated effects, and only while on screen (TimelineView pauses offscreen).
struct KeyboardPreview: View {
    let state: LightingState
    var selectedZone: Int?
    var onSelectZone: ((Int) -> Void)?

    private var isAnimated: Bool {
        state.isOn && state.mode.effect != .staticColor
    }

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1 / 30, paused: !isAnimated)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let colors = state.isOn ? state.mode.previewColors(at: t) : Array(repeating: AuraColor.black, count: 4)
                Canvas { ctx, size in
                    KeyboardLayout.draw(in: &ctx, size: size, colors: colors,
                                        intensity: Self.intensity(for: state),
                                        selectedZone: selectedZone)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                guard let onSelectZone, geo.size.width > 0 else { return }
                onSelectZone(KeyboardLayout.Metrics(size: geo.size).zone(atX: location.x))
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Keyboard lighting preview")
        .accessibilityValue(state.isOn ? (state.mode.effect?.title ?? "Off") : "Off")
    }

    static func intensity(for state: LightingState) -> Double {
        switch state.effectiveBrightness {
        case 0: return 0
        case 1: return 0.45
        case 2: return 0.72
        default: return 1
        }
    }
}

private enum KeyboardLayout {
    /// Key widths in key units per row. Main block is 15 units, numpad is 4.
    static let mainRows: [[Double]] = [
        Array(repeating: 1, count: 15),
        Array(repeating: 1, count: 13) + [2],
        [1.5] + Array(repeating: 1, count: 12) + [1.5],
        [1.75] + Array(repeating: 1, count: 11) + [2.25],
        [2.25] + Array(repeating: 1, count: 10) + [2.75],
        [1.25, 1.25, 1.25, 6.25, 1.25, 1.25, 1.25, 1.25],
    ]
    static let numpadRows: [[Double]] = Array(repeating: [1, 1, 1, 1], count: 6)
    static let totalUnits = 15 + 0.5 + 4.0
    static let rowUnits = 5.6

    /// Where the keyboard sits inside the view. Shared by drawing and hit-testing so a
    /// tap always selects the zone drawn under it, even when the keyboard is letterboxed.
    struct Metrics {
        let unit: CGFloat
        let width: CGFloat
        let origin: CGPoint

        init(size: CGSize) {
            let area = CGRect(origin: .zero, size: size).insetBy(dx: 18, dy: 18)
            unit = max(0, min(area.width / totalUnits, area.height / rowUnits))
            width = unit * totalUnits
            origin = CGPoint(x: area.midX - width / 2, y: area.midY - unit * rowUnits / 2)
        }

        func zone(atX x: CGFloat) -> Int {
            guard width > 0 else { return 0 }
            return min(3, max(0, Int((x - origin.x) / width * 4)))
        }
    }

    static func draw(in ctx: inout GraphicsContext, size: CGSize, colors: [AuraColor], intensity: Double, selectedZone: Int?) {
        let panel = CGRect(origin: .zero, size: size)
        ctx.fill(Path(roundedRect: panel, cornerRadius: 14), with: .color(Color(white: 0.07)))

        let metrics = Metrics(size: size)
        let unit = metrics.unit, width = metrics.width, origin = metrics.origin
        let gap = unit * 0.12

        func zone(atX x: CGFloat) -> Int { metrics.zone(atX: x) }
        func lit(_ index: Int) -> Color {
            intensity == 0 ? .clear : Color(colors[index]).opacity(intensity)
        }

        // Underglow: one soft wash per zone.
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: unit * 1.6))
            for i in 0..<4 where intensity > 0 {
                let rect = CGRect(x: origin.x + width * CGFloat(i) / 4, y: origin.y, width: width / 4, height: unit * 5.6)
                layer.fill(Path(rect), with: .color(Color(colors[i]).opacity(0.28 * intensity)))
            }
        }

        func drawRows(_ rows: [[Double]], startX: CGFloat) {
            var y = origin.y
            for (r, row) in rows.enumerated() {
                let height = r == 0 ? unit * 0.6 : unit
                var x = startX
                for w in row {
                    let rect = CGRect(x: x + gap / 2, y: y + gap / 2, width: unit * w - gap, height: height - gap)
                    let path = Path(roundedRect: rect, cornerRadius: unit * 0.14)
                    ctx.fill(path, with: .color(Color(white: 0.16)))
                    ctx.fill(path, with: .color(lit(zone(atX: rect.midX)).opacity(0.85)))
                    ctx.stroke(path, with: .color(.white.opacity(0.06)), lineWidth: 0.5)
                    x += unit * w
                }
                y += height
            }
        }

        drawRows(mainRows, startX: origin.x)
        drawRows(numpadRows, startX: origin.x + unit * 15.5)

        if let selectedZone {
            let rect = CGRect(x: origin.x + width * CGFloat(selectedZone) / 4, y: origin.y - 6,
                              width: width / 4, height: unit * 5.6 + 12)
            ctx.stroke(Path(roundedRect: rect, cornerRadius: 8), with: .color(.white.opacity(0.7)),
                       style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
        }
    }
}
