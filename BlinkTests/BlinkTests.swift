import XCTest
@testable import Blink

// 앱의 순수 로직만 검증한다. 화면·시스템 동작은 docs/CHECKLIST.md에서 확인한다.
final class BlinkTests: XCTestCase {
    func testTrackerReportsOnlyRealChanges() {
        var tracker = InputSourceTracker()
        XCTAssertNil(tracker.update(nil))  // 이름을 못 읽으면 무시
        _ = tracker.update("ABC")  // 시작 시 현재 값 기록

        XCTAssertNil(tracker.update("ABC"))  // 같은 이름으로 알림이 또 와도 무시
        let change = tracker.update("2-Set Korean")
        XCTAssertEqual(change?.from, "ABC")
        XCTAssertEqual(change?.to, "2-Set Korean")
        XCTAssertNil(tracker.update("2-Set Korean"))
        XCTAssertNil(tracker.update(nil))
        XCTAssertEqual(tracker.update("ABC")?.from, "2-Set Korean")
    }

    func testTrackerRemembersPreviousSource() {
        var tracker = InputSourceTracker()
        _ = tracker.update("ABC")
        XCTAssertNil(tracker.previous)  // 시작 값은 전환이 아니다
        _ = tracker.update("2-Set Korean")
        XCTAssertEqual(tracker.previous, "ABC")
        _ = tracker.update("2-Set Korean")  // 같은 이름 알림은 무시
        XCTAssertEqual(tracker.previous, "ABC")
        _ = tracker.update("Kana")
        XCTAssertEqual(tracker.previous, "2-Set Korean")
    }

    // 미니 HUD 오른쪽: 직전 입력소스, 없으면 켜진 목록에서 현재가 아닌 첫 번째, 그것도 없으면 nil("없음").
    func testNextSourceForPreview() {
        let next = { InputSourceTracker.next(current: $0, previous: $1, enabled: $2) }
        // 1개: 바꿀 곳이 없다
        XCTAssertNil(next("ABC", nil, ["ABC"]))
        // 2개: 다른 하나
        XCTAssertEqual(next("ABC", nil, ["ABC", "2-Set Korean"]), "2-Set Korean")
        // 3개 이상: 전환한 적이 없으면 목록 순서, 있으면 직전 것(⌃Space·한/영 키가 돌아가는 곳)
        let three = ["ABC", "2-Set Korean", "Kana"]
        XCTAssertEqual(next("Kana", nil, three), "ABC")
        XCTAssertEqual(next("Kana", "2-Set Korean", three), "2-Set Korean")
        // 직전 것이 목록에서 빠졌으면 목록에서 고른다
        XCTAssertEqual(next("Kana", "Dvorak", three), "ABC")
        // 목록을 못 읽었으면(빈 목록) 직전 것을 믿는다
        XCTAssertEqual(next("Kana", "ABC", []), "ABC")
        XCTAssertNil(next("ABC", "ABC", []))
    }

    func testDurationSnapsToHalfSecondsWithinRange() {
        let cases: [(Double, Double)] = [(0.2, 0.5), (-1, 0.5), (0.5, 0.5), (1.2, 1.0), (1.3, 1.5), (2.75, 3.0), (5.0, 5.0), (7, 5.0)]
        for (input, expected) in cases {
            XCTAssertEqual(SettingsWindow.snapped(input), expected, "\(input)")
        }
    }

    func testDurationFromTextFallsBackToCurrentValue() {
        XCTAssertEqual(SettingsWindow.duration(from: "2.3", current: 1.0), 2.5)
        XCTAssertEqual(SettingsWindow.duration(from: "9", current: 1.0), 5.0)
        XCTAssertEqual(SettingsWindow.duration(from: "abc", current: 1.5), 1.5)
        XCTAssertEqual(SettingsWindow.duration(from: "", current: 2.0), 2.0)
        XCTAssertEqual(SettingsWindow.duration(from: "nan", current: 2.0), 2.0)
    }

    func testPanelWidth() {
        // 480pt 안이면 그대로
        XCTAssertEqual(HUD.panelWidth(fitting: 300, from: 60, ellipsis: 20, maxWidth: 480), 300)
        // 넘치면 480pt로 줄인다('변경 전' 말줄임)
        XCTAssertEqual(HUD.panelWidth(fitting: 600, from: 300, ellipsis: 20, maxWidth: 480), 480)
        // '변경 후'만으로 480pt를 넘으면 '변경 전'을 "…"만 남기고 넓힌다
        XCTAssertEqual(HUD.panelWidth(fitting: 700, from: 100, ellipsis: 20, maxWidth: 480), 620)
        // '변경 전'을 숨기면 자를 것이 없으므로 '변경 후'에 맞춘다
        XCTAssertEqual(HUD.panelWidth(fitting: 700, from: 0, ellipsis: 0, maxWidth: 480), 700)
    }

    // MARK: 모양

    func testSizeScalesTypeAndMetrics() {
        var look = HUDAppearance()
        XCTAssertEqual([look.scaled(28), look.scaled(20), look.scaled(480)], [28, 20, 480])
        look.size = .small
        XCTAssertEqual([look.scaled(28), look.scaled(20), look.scaled(480)], [22, 16, 384])
        look.size = .large
        XCTAssertEqual([look.scaled(28), look.scaled(20), look.scaled(480)], [36, 26, 624])
    }

    func testCornerRadius() {
        var look = HUDAppearance()
        XCTAssertEqual(look.cornerRadius(height: 66, standard: 18), 18)
        look.corners = .square
        XCTAssertEqual(look.cornerRadius(height: 66, standard: 18), 0)
        look.corners = .pill
        XCTAssertEqual(look.cornerRadius(height: 66, standard: 18), 33)
    }

    // 프리셋 글자는 배경과 4.5:1, 화살표는 3:1 이상(디자인 시스템 규칙).
    func testPresetsAreReadableInBothModes() throws {
        for theme in HUDTheme.presets {
            for mode in HUDMode.allCases {
                let c = try XCTUnwrap(theme.presetColors(mode))
                XCTAssertGreaterThanOrEqual(c.to.contrast(with: c.background), 4.5, "\(theme) \(mode) to")
                XCTAssertGreaterThanOrEqual(c.from.contrast(with: c.background), 4.5, "\(theme) \(mode) from")
                XCTAssertGreaterThanOrEqual(c.arrow.contrast(with: c.background), 3, "\(theme) \(mode) arrow")
            }
        }
        XCTAssertEqual(RGBA(hex: 0x000000).contrast(with: RGBA(hex: 0xffffff)), 21, accuracy: 0.01)
    }

    func testColorsFollowModeAndReduceTransparency() {
        var look = HUDAppearance()
        XCTAssertEqual(look.colors(.light).to, RGBA(hex: 0x1d1d1f))
        XCTAssertEqual(look.colors(.dark).to, RGBA(hex: 0xffffff))
        // 투명도 줄이기: 기본 테마는 불투명 surface
        XCTAssertEqual(look.colors(.light, reduceTransparency: true).background, RGBA(hex: 0xf5f5f7))
        // 다른 테마는 같은 색을 불투명하게
        look.select(.gruvbox)
        XCTAssertEqual(look.colors(.dark).background.alpha, 0.92)
        XCTAssertEqual(look.colors(.dark, reduceTransparency: true).background, RGBA(hex: 0x282828))
        // Dracula는 라이트에서도 같은 색
        look.select(.dracula)
        XCTAssertEqual(look.colors(.light), look.colors(.dark))
    }

    // 사용자 지정은 처음 고를 때 직전 테마 색에서 시작하고, 그 뒤로는 저장한 색을 유지한다.
    func testCustomStartsFromPreviousThemeOnce() throws {
        var look = HUDAppearance()
        look.select(.dracula)
        look.select(.custom)
        let dracula = try XCTUnwrap(HUDTheme.dracula.presetColors(.light))
        XCTAssertEqual(look.custom(.light), CustomColors(text: dracula.to, background: dracula.background))
        XCTAssertEqual(look.custom(.dark)?.text, dracula.to)

        var edited = try XCTUnwrap(look.custom(.dark))
        edited.background = RGBA(hex: 0x123456, alpha: 0.5)
        look.setCustom(edited, for: .dark)
        look.select(.gruvbox)
        look.select(.custom)
        XCTAssertEqual(look.custom(.dark), edited)  // Gruvbox 색으로 덮지 않는다
        XCTAssertEqual(look.custom(.light)?.text, dracula.to)  // 라이트는 그대로
    }

    func testCustomColorsDeriveFromAndArrow() throws {
        var look = HUDAppearance()
        look.select(.custom)
        look.setCustom(CustomColors(text: RGBA(hex: 0x112233), background: RGBA(hex: 0xffeedd, alpha: 0.7)), for: .light)
        let c = look.colors(.light)
        XCTAssertEqual(c.to, RGBA(hex: 0x112233))
        XCTAssertEqual(c.from, RGBA(hex: 0x112233, alpha: 0.6))
        XCTAssertEqual(c.arrow, RGBA(hex: 0x0a66d6))  // 강조색
        XCTAssertEqual(c.background.alpha, 0.7)
        XCTAssertEqual(look.colors(.light, reduceTransparency: true).background.alpha, 1)
    }

    func testLowContrastWarning() {
        XCTAssertTrue(CustomColors(text: RGBA(hex: 0x777777), background: RGBA(hex: 0x888888)).isLowContrast)
        XCTAssertFalse(CustomColors(text: RGBA(hex: 0x000000), background: RGBA(hex: 0xffffff)).isLowContrast)
    }

    func testAppearanceSavesAndFallsBackToDefault() {
        XCTAssertEqual(HUDAppearance(data: nil), .standard)
        XCTAssertEqual(HUDAppearance(data: Data("garbage".utf8)), .standard)
        var look = HUDAppearance()
        look.select(.rosePine)
        look.select(.custom)
        look.size = .large
        look.corners = .pill
        look.bold = true
        look.showsFrom = false
        XCTAssertEqual(HUDAppearance(data: look.data), look)
    }

    // 메뉴바(위)와 Dock(아래 80pt)을 뺀 1440×900 화면의 visibleFrame, 여백 24pt, HUD 300×66.
    private let visible = CGRect(x: 0, y: 80, width: 1440, height: 795)
    private let hud = CGSize(width: 300, height: 66)

    func testPositionClampsAndNamesPresets() {
        XCTAssertEqual(HUDPosition(x: 2, y: -1), HUDPosition(x: 1, y: 0))
        XCTAssertEqual(HUDPosition(x: .nan, y: .infinity), .center)
        XCTAssertEqual(HUDPosition.presets.count, 9)
        XCTAssertEqual(HUDPosition.center.presetIndex, 4)
        XCTAssertEqual(HUDPosition(x: 1, y: 0).presetIndex, 2)  // 오른쪽 위
        XCTAssertNil(HUDPosition(x: 0.3, y: 0.5).presetIndex)  // 직접 지정
    }

    func testOriginKeepsHUDInsideVisibleFrame() {
        // 왼쪽 위: 여백에 붙는다(y는 위로 증가하므로 위쪽 가장자리 = maxY - 여백 - 높이).
        XCTAssertEqual(HUDPosition(x: 0, y: 0).origin(size: hud, in: visible, margin: 24), CGPoint(x: 24, y: 785))
        XCTAssertEqual(HUDPosition.center.origin(size: hud, in: visible, margin: 24), CGPoint(x: 570, y: 445))
        // 오른쪽 아래: Dock 위 여백에 붙는다.
        XCTAssertEqual(HUDPosition(x: 1, y: 1).origin(size: hud, in: visible, margin: 24), CGPoint(x: 1116, y: 104))
        // HUD가 영역보다 넓으면 위치와 상관없이 가로는 가운데.
        let wide = CGSize(width: 1500, height: 66)
        XCTAssertEqual(HUDPosition(x: 0, y: 0).origin(size: wide, in: visible, margin: 24).x, -30)
    }

    func testDraggedPositionSnapsToNearPreset() {
        func drag(_ x: CGFloat, _ y: CGFloat) -> HUDPosition {
            HUDPosition.dragged(to: CGPoint(x: x, y: y), size: hud, in: visible, margin: 24, snap: 12)
        }
        XCTAssertEqual(drag(1110, 780), HUDPosition(x: 1, y: 0))  // 오른쪽 위에서 8pt 떨어짐 → 붙음
        XCTAssertEqual(drag(-100, 2000), HUDPosition(x: 0, y: 0))  // 영역 밖 → 가장자리로
        let free = drag(800, 600)  // 프리셋에서 멀면 직접 지정
        XCTAssertNil(free.presetIndex)
        XCTAssertEqual(free.origin(size: hud, in: visible, margin: 24), CGPoint(x: 800, y: 600))
    }

    // 지원 언어 10개가 앱에 들어 있고, 각 언어가 영어와 같은 문자열을 빠짐없이 번역했는지 본다.
    func testEveryLanguageTranslatesEveryString() throws {
        let languages = ["en", "ko", "ja", "zh-Hans", "zh-Hant", "ru", "de", "fr", "es", "pt-BR"]
        func strings(_ language: String) -> [String: String]? {
            Bundle.main.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: language)
                .flatMap { NSDictionary(contentsOf: $0) as? [String: String] }
        }
        let english = try XCTUnwrap(strings("en"))
        XCTAssertFalse(english.isEmpty)
        for language in languages {
            let translated = try XCTUnwrap(strings(language), language)
            XCTAssertEqual(Set(translated.keys), Set(english.keys), language)
            XCTAssertFalse(translated.values.contains(where: \.isEmpty), language)
        }
        // 번역 대신 영어 원문이 들어가지 않았는지 하나만 확인한다.
        XCTAssertEqual(strings("ko")?["About Blink"], "Blink 정보")
    }
}
