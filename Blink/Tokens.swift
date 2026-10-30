import AppKit

// 디자인 시스템 tokens.json의 색. 라이트/다크는 시스템 설정을 따른다.
enum Tokens {
    static let surface = dynamic(light: NSColor(hex: 0xf5f5f7), dark: NSColor(hex: 0x1c1c1e))
    static let ink = dynamic(light: NSColor(hex: 0x1d1d1f), dark: NSColor(hex: 0xf2f2f7))
    static let muted = dynamic(light: NSColor(hex: 0x6e6e73), dark: NSColor(hex: 0xa1a1a6))
    static let line = dynamic(light: NSColor(hex: 0xd2d2d7), dark: NSColor(hex: 0x3a3a3c))
    static let accent = dynamic(light: NSColor(hex: 0x0a66d6), dark: NSColor(hex: 0x4c9dff))
    static let signalOn = dynamic(light: NSColor(hex: 0x1f7a3d), dark: NSColor(hex: 0x4cd07d))
    // 1.4.0부터. 통계의 입력소스 순위별 색(비율 막대·범례·앱별 막대 안).
    static let source1 = accent
    static let source2 = dynamic(light: NSColor(hex: 0x0a3d80), dark: NSColor(hex: 0xa8cfff))
    static let source3 = dynamic(light: NSColor(hex: 0x4a8fe8), dark: NSColor(hex: 0x2a6fd1))
    static let sourceOther = dynamic(light: NSColor(hex: 0x8e8e93), dark: NSColor(hex: 0x636366))
    static let groupBackground = dynamic(light: NSColor(hex: 0xffffff), dark: NSColor(hex: 0xffffff, alpha: 0.05))

    private static func dynamic(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { $0.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light }
    }
}

// HUD 색(hud-*)은 모양에 따라 바뀌므로 HUDAppearance에 있다.

extension NSColor {
    convenience init(_ rgba: RGBA) {
        self.init(srgbRed: rgba.red, green: rgba.green, blue: rgba.blue, alpha: rgba.alpha)
    }

    // 색 우물에서 고른 색을 sRGB 값으로 바꾼다.
    var rgba: RGBA? {
        usingColorSpace(.sRGB).map { RGBA(red: $0.redComponent, green: $0.greenComponent, blue: $0.blueComponent, alpha: $0.alphaComponent) }
    }
}

extension NSAppearance {
    var hudMode: HUDMode { bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .dark : .light }
}

private extension NSColor {
    convenience init(hex: Int, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat(hex >> 16 & 0xff) / 255, green: CGFloat(hex >> 8 & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
    }
}
