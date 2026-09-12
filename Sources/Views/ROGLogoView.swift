import SwiftUI
import Cocoa

public struct ROGLogoView: View {
    public let size: CGFloat
    public let tintColor: Color?

    public init(size: CGFloat = 24, tintColor: Color? = nil) {
        self.size = size
        self.tintColor = tintColor
    }

    public var body: some View {
        if let image = loadLogoImage() {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size * 0.62)
                .shadow(color: Color.white.opacity(0.15), radius: 3, y: 1)
        } else {
            // Crisp fallback: Pure White Vector ROG Eye
            ROGEyeVectorShape()
                .fill(tintColor ?? Color.white)
                .frame(width: size, height: size * 0.62)
        }
    }

    private func loadLogoImage() -> NSImage? {
        // 1. Bundle Resources (Prioritize Official SVG Emblem)
        let candidates: [(String, String)] = [
            ("rog_emblem_white", "svg"),
            ("rog_logo_white", "png"),
            ("rog_emblem_white", "png")
        ]
        for (name, ext) in candidates {
            if let path = Bundle.main.path(forResource: name, ofType: ext),
               let img = NSImage(contentsOfFile: path) {
                return img
            }
        }

        // 2. Relative project search
        let projectPaths = [
            "./Resources/rog_emblem_white.svg",
            "./Resources/rog_logo_white.png",
            "/Applications/ROG Gaming Center.app/Contents/Resources/rog_emblem_white.svg",
            "/Applications/ROG Gaming Center.app/Contents/Resources/rog_logo_white.png"
        ]
        for p in projectPaths {
            if FileManager.default.fileExists(atPath: p), let img = NSImage(contentsOfFile: p) {
                return img
            }
        }
        return nil
    }
}

/// Dynamic vector geometry for ASUS Republic of Gamers Fearless Eye
public struct ROGEyeVectorShape: Shape {
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Upper Brow / Wing Arc
        path.move(to: CGPoint(x: w * 0.98, y: h * 0.08))
        path.addCurve(to: CGPoint(x: w * 0.06, y: h * 0.58),
                      control1: CGPoint(x: w * 0.65, y: h * 0.10),
                      control2: CGPoint(x: w * 0.30, y: h * 0.28))
        path.addCurve(to: CGPoint(x: w * 0.20, y: h * 0.64),
                      control1: CGPoint(x: w * 0.10, y: h * 0.60),
                      control2: CGPoint(x: w * 0.15, y: h * 0.62))
        path.addCurve(to: CGPoint(x: w * 0.92, y: h * 0.22),
                      control1: CGPoint(x: w * 0.45, y: h * 0.40),
                      control2: CGPoint(x: w * 0.72, y: h * 0.26))
        path.closeSubpath()

        // Lower Eye & Pupil Frame
        path.move(to: CGPoint(x: w * 0.25, y: h * 0.68))
        path.addCurve(to: CGPoint(x: w * 0.65, y: h * 0.98),
                      control1: CGPoint(x: w * 0.35, y: h * 0.88),
                      control2: CGPoint(x: w * 0.50, y: h * 0.98))
        path.addCurve(to: CGPoint(x: w * 0.88, y: h * 0.38),
                      control1: CGPoint(x: w * 0.78, y: h * 0.80),
                      control2: CGPoint(x: w * 0.86, y: h * 0.55))
        path.addLine(to: CGPoint(x: w * 0.72, y: h * 0.48))
        path.addCurve(to: CGPoint(x: w * 0.40, y: h * 0.65),
                      control1: CGPoint(x: w * 0.62, y: h * 0.62),
                      control2: CGPoint(x: w * 0.50, y: h * 0.65))
        path.closeSubpath()

        return path
    }
}

