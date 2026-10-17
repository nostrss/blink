import AppKit

// 디자인 시스템 tokens.json의 색. 라이트/다크는 시스템 설정을 따른다.
enum Tokens {
    static let surface = dynamic(light: NSColor(hex: 0xf5f5f7), dark: NSColor(hex: 0x1c1c1e))
    static let ink = dynamic(light: NSColor(hex: 0x1d1d1f), dark: NSColor(hex: 0xf2f2f7))
    static let muted = dynamic(light: NSColor(hex: 0x6e6e73), dark: NSColor(hex: 0xa1a1a6))
    static let line = dynamic(light: NSColor(hex: 0xd2d2d7), dark: NSColor(hex: 0x3a3a3c))
    static let hudBg = dynamic(light: NSColor(hex: 0xf6f6f8, alpha: 0.55), dark: NSColor(hex: 0x28282a, alpha: 0.55))
    static let hudInk = dynamic(light: NSColor(hex: 0x1d1d1f), dark: .white)
    static let accent = dynamic(light: NSColor(hex: 0x0a66d6), dark: NSColor(hex: 0x4c9dff))
    static let signalOn = dynamic(light: NSColor(hex: 0x1f7a3d), dark: NSColor(hex: 0x4cd07d))

    private static func dynamic(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { $0.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light }
    }
}

private extension NSColor {
    convenience init(hex: Int, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat(hex >> 16 & 0xff) / 255, green: CGFloat(hex >> 8 & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
    }
}
