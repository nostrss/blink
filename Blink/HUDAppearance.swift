import CoreGraphics
import Foundation

// sRGB 색 하나. 값은 0–1. AppKit 없이 계산하려고 NSColor 대신 쓴다.
struct RGBA: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        (self.red, self.green, self.blue, self.alpha) = (red, green, blue, alpha)
    }

    init(hex: Int, alpha: Double = 1) {
        self.init(red: Double(hex >> 16 & 0xff) / 255, green: Double(hex >> 8 & 0xff) / 255, blue: Double(hex & 0xff) / 255, alpha: alpha)
    }

    func withAlpha(_ alpha: Double) -> RGBA { RGBA(red: red, green: green, blue: blue, alpha: alpha) }

    // WCAG 대비(1–21). 알파는 무시한다.
    func contrast(with other: RGBA) -> Double {
        let (a, b) = (luminance, other.luminance)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    private var luminance: Double {
        func linear(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }
}

enum HUDMode: CaseIterable { case light, dark }

// HUD 한 번을 칠할 색. 배경의 알파가 덧칠 색의 불투명도이고, blur는 그 아래 흐림 재질을 얼마나 보일지(0–1)다.
struct HUDColors: Equatable {
    var background: RGBA
    var from: RGBA
    var arrow: RGBA
    var to: RGBA
    var blur: Double = 1

    // Caps Lock HUD의 기호(⇪)와 단어 색. 켜짐은 밝게(화살표 색·변경 후 색), 꺼짐은 흐리게(둘 다 변경 전 색).
    func capsLock(on: Bool) -> (symbol: RGBA, word: RGBA) {
        on ? (arrow, to) : (from, from)
    }
}

enum HUDTheme: String, Codable, CaseIterable {
    case standard, classic, highContrast, dracula, gruvbox, rosePine, custom

    static let presets: [HUDTheme] = [.standard, .classic, .highContrast, .dracula, .gruvbox, .rosePine]

    // 디자인 시스템 tokens.json의 hud-* 색. 사용자 지정은 nil.
    func presetColors(_ mode: HUDMode) -> HUDColors? {
        let light = mode == .light
        func colors(_ bg: Int, _ alpha: Double, _ from: Int, _ arrow: Int, _ to: Int) -> HUDColors {
            HUDColors(background: RGBA(hex: bg, alpha: alpha), from: RGBA(hex: from), arrow: RGBA(hex: arrow), to: RGBA(hex: to))
        }
        switch self {
        case .standard: return light ? colors(0xf6f6f8, 0.55, 0x6e6e73, 0x0a66d6, 0x1d1d1f) : colors(0x28282a, 0.55, 0xa1a1a6, 0x4c9dff, 0xffffff)
        case .classic: return HUDTheme.standard.presetColors(mode)  // 1.1.0까지의 기본 모양. 색은 기본과 같고 유리만 쓰지 않는다
        case .highContrast: return light ? colors(0xffffff, 1, 0x4a4a4f, 0x0a66d6, 0x000000) : colors(0x000000, 1, 0xc7c7cc, 0x4c9dff, 0xffffff)
        case .dracula: return colors(0x282a36, 0.92, 0xbd93f9, 0xff79c6, 0xf8f8f2)  // 다크 전용 테마라 라이트도 같은 색
        case .gruvbox: return light ? colors(0xfbf1c7, 0.92, 0x665c54, 0xaf3a03, 0x3c3836) : colors(0x282828, 0.92, 0xa89984, 0xfe8019, 0xebdbb2)
        case .rosePine: return light ? colors(0xfaf4ed, 0.92, 0x286983, 0xb4637a, 0x575279) : colors(0x191724, 0.92, 0x9ccfd8, 0xebbcba, 0xe0def4)
        case .custom: return nil
        }
    }
}

// 사용자 지정 테마에서 사용자가 고르는 값. text는 '변경 후' 글자색, 배경의 알파가 배경 불투명도다.
struct CustomColors: Codable, Equatable {
    var text: RGBA
    var from: RGBA
    var arrow: RGBA
    var background: RGBA

    init(text: RGBA, from: RGBA, arrow: RGBA, background: RGBA) {
        (self.text, self.from, self.arrow, self.background) = (text, from, arrow, background)
    }

    init(_ colors: HUDColors) {
        self.init(text: colors.to, from: colors.from, arrow: colors.arrow, background: colors.background)
    }

    // 예전에는 글자색과 배경색만 저장했다. 없으면 변경 전은 글자색을 흐리게, 화살표는 강조색으로 채운다.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        text = try c.decode(RGBA.self, forKey: .text)
        background = try c.decode(RGBA.self, forKey: .background)
        from = try c.decodeIfPresent(RGBA.self, forKey: .from) ?? text.withAlpha(0.6)
        arrow = try c.decodeIfPresent(RGBA.self, forKey: .arrow) ?? RGBA(hex: 0x0a66d6)
    }

    // 변경 후·변경 전 글자와 배경의 대비가 3:1보다 낮거나, 배경이 거의 투명해(30% 미만) 뒤 화면에 글자가 묻힐 수 있으면
    // 설정 창에 경고를 띄운다(막지는 않는다).
    var isLowContrast: Bool { min(text.contrast(with: background), from.contrast(with: background)) < 3 || background.alpha < 0.3 }
}

// 설정 창 '모양'에서 정하는 HUD 모양. 기본값이 지금까지의 HUD 그대로다.
struct HUDAppearance: Codable, Equatable {
    enum Size: String, Codable, CaseIterable {
        case small, medium, large
        var scale: CGFloat {
            switch self {
            case .small: 0.8
            case .medium: 1
            case .large: 1.3
            }
        }
    }

    enum Corners: String, Codable, CaseIterable { case square, standard, pill }

    // 입력소스를 이름으로 쓸지 약자로 쓸지.
    enum Display: String, Codable, CaseIterable { case name, abbreviation }

    var theme = HUDTheme.standard
    var size = Size.medium
    var corners = Corners.standard
    var bold = false
    var showsFrom = true
    var display = Display.name
    // 사용자 지정으로 바꿀 때 그때 쓰던 테마 색으로 채우고, 사용자 지정에 있는 동안 고친 값을 저장한다.
    var customLight: CustomColors?
    var customDark: CustomColors?

    static let standard = HUDAppearance()

    // 저장된 값을 읽는다. 없거나 읽을 수 없으면 기본 모양.
    init(data: Data?) {
        self = data.flatMap { try? JSONDecoder().decode(Self.self, from: $0) } ?? Self()
    }

    init() {}

    // 나중에 생긴 값(표시 방식)이 없는 예전 저장값도 읽도록, 없는 키는 기본값으로 채운다.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // 모르는 테마(1.2.0 개발판의 "glass" 등)는 다른 설정을 버리지 않고 기본으로 읽는다.
        theme = try c.decodeIfPresent(String.self, forKey: .theme).map { HUDTheme(rawValue: $0) ?? .standard } ?? theme
        size = try c.decodeIfPresent(Size.self, forKey: .size) ?? size
        corners = try c.decodeIfPresent(Corners.self, forKey: .corners) ?? corners
        bold = try c.decodeIfPresent(Bool.self, forKey: .bold) ?? bold
        showsFrom = try c.decodeIfPresent(Bool.self, forKey: .showsFrom) ?? showsFrom
        display = try c.decodeIfPresent(Display.self, forKey: .display) ?? display
        customLight = try c.decodeIfPresent(CustomColors.self, forKey: .customLight)
        customDark = try c.decodeIfPresent(CustomColors.self, forKey: .customDark)
    }

    var data: Data { (try? JSONEncoder().encode(self)) ?? Data() }

    // 테마를 고른다.
    mutating func select(_ newTheme: HUDTheme) {
        // 프리셋에서 사용자 지정으로 바꾸면 그 프리셋의 라이트·다크 색을 그대로 이어받아, 바꾸는 순간 모습이 바뀌지 않는다.
        // 이미 사용자 지정이면 지금 색을 그대로 두고, 저장된 색이 없으면 기본 테마에서 시작한다.
        if newTheme == .custom {
            let base = theme == .custom ? HUDTheme.standard : theme
            if theme != .custom || customLight == nil { customLight = CustomColors(base.presetColors(.light)!) }
            if theme != .custom || customDark == nil { customDark = CustomColors(base.presetColors(.dark)!) }
        }
        theme = newTheme
    }

    func custom(_ mode: HUDMode) -> CustomColors? { mode == .light ? customLight : customDark }

    mutating func setCustom(_ colors: CustomColors, for mode: HUDMode) {
        if mode == .light { customLight = colors } else { customDark = colors }
    }

    // 기본 테마를 유리로 그릴 때 유리에 얹는 tint의 불투명도. 색은 그 모드의 기본 테마 배경색이다.
    static let glassTint = 0.3

    // 유리(NSGlassEffectView)로 그리는가. glassAvailable은 macOS 26 이상인지다.
    // 기본 테마만 유리로 그린다. '투명도 줄이기'가 켜져 있으면 시스템에 맡기지 않고 기본 테마의 불투명 판으로 그린다.
    func usesGlass(glassAvailable: Bool, reduceTransparency: Bool) -> Bool {
        theme == .standard && glassAvailable && !reduceTransparency
    }

    // 지금 모드에서 칠할 색. '투명도 줄이기'가 켜져 있으면 배경을 불투명하게 하고, 기본·클래식 테마는 surface로 바꾼다.
    func colors(_ mode: HUDMode, reduceTransparency: Bool = false) -> HUDColors {
        var colors: HUDColors
        if theme == .custom, let custom = custom(mode) {
            // 흐림 = min(1, 불투명도 ÷ 0.55): 기본(0.55)·Dracula 계열(0.92) 이상에서는 프리셋처럼 흐림을 다 깔고, 그 아래로 내리면 흐림도 옅어진다.
            colors = HUDColors(background: custom.background, from: custom.from, arrow: custom.arrow, to: custom.text, blur: min(1, custom.background.alpha / 0.55))
        } else {
            colors = (theme.presetColors(mode) ?? HUDTheme.standard.presetColors(mode))!
        }
        if reduceTransparency {
            colors.background = [.standard, .classic].contains(theme) ? RGBA(hex: mode == .light ? 0xf5f5f7 : 0x1c1c1e) : colors.background.withAlpha(1)
        }
        return colors
    }

    // 표시 방식에 맞는 글자. to가 nil이면 바꿀 입력소스가 없다는 뜻("없음").
    // 약자가 같으면(ABC와 U.S.는 둘 다 EN) 무엇이 바뀌었는지 알 수 없으므로 그 전환만 이름으로 보여 준다.
    func texts(from: InputSourceLabel, to: InputSourceLabel?) -> (from: String, to: String?) {
        guard display == .abbreviation, from.abbreviation != to?.abbreviation else { return (from.name, to?.name) }
        return (from.abbreviation, to?.abbreviation)
    }

    // 약자 배지: 약자만, 변경 전 없이 하나만 보일 때. 사방 패딩을 같게 하고 폭이 높이보다 좁아지지 않게 해 정사각형으로 그린다.
    var isBadge: Bool { display == .abbreviation && !showsFrom }

    // 글자 크기·패딩·간격·최대 폭에 크기 배율을 곱해 정수 pt로 맞춘다.
    func scaled(_ value: CGFloat) -> CGFloat { (value * size.scale).rounded() }

    // 각지게는 0, 기본은 standard(HUD 18, 미니 HUD 6), 알약은 높이의 절반. 크기 배율은 곱하지 않는다.
    func cornerRadius(height: CGFloat, standard: CGFloat) -> CGFloat {
        switch corners {
        case .square: 0
        case .standard: standard
        case .pill: height / 2
        }
    }
}
