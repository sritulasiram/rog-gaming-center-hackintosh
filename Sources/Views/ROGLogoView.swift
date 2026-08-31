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
                .frame(width: size, height: size)
                .shadow(color: Color(red: 0.9, green: 0.05, blue: 0.15).opacity(0.25), radius: 2, y: 1)
        } else {
            // Crisp fallback: Vector ROG Eye
            ROGEyeVectorShape()
                .fill(tintColor ?? Color(red: 0.92, green: 0.06, blue: 0.16))
                .frame(width: size, height: size * 0.72)
        }
    }

    private func loadLogoImage() -> NSImage? {
        // 1. Bundle Resource
        if let bundlePath = Bundle.main.path(forResource: "logo", ofType: "png"),
           let img = NSImage(contentsOfFile: bundlePath) {
            return img
        }
        if let bundlePath = Bundle.main.path(forResource: "app_icon", ofType: "png"),
           let img = NSImage(contentsOfFile: bundlePath) {
            return img
        }

        // 2. Relative project search
        let projectPaths = [
            "./Resources/logo.png",
            "./Resources/app_icon.png",
            "/Applications/ROG Gaming Center.app/Contents/Resources/logo.png"
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

