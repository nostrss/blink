import AppKit
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

    // 약자: 일본어는 입력 모드로, 한·중은 언어로, 그 밖은 언어 코드 대문자, 언어가 없으면 이름 첫 글자.
    func testAbbreviation() {
        let abbreviation = { InputSourceLabel.abbreviation(id: $0, languages: $1, name: $2) }
        let kotoeri = "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese"
        XCTAssertEqual(abbreviation(kotoeri, ["ja"], "Hiragana"), "あ")
        XCTAssertEqual(abbreviation(kotoeri + ".Katakana", ["ja"], "Katakana"), "ア")
        XCTAssertEqual(abbreviation(kotoeri + ".HalfWidthKana", ["ja"], "Half-width Katakana"), "ｱ")
        XCTAssertEqual(abbreviation(kotoeri + ".FullWidthRoman", ["ja"], "Full-width Romaji"), "Ａ")
        XCTAssertEqual(abbreviation("com.apple.inputmethod.Korean.2SetKorean", ["ko"], "2-Set Korean"), "한")
        XCTAssertEqual(abbreviation("com.apple.inputmethod.SCIM.ITABC", ["zh-Hans"], "Pinyin – Simplified"), "简")
        XCTAssertEqual(abbreviation("com.apple.inputmethod.TCIM.Zhuyin", ["zh-Hant"], "Zhuyin – Traditional"), "繁")
        XCTAssertEqual(abbreviation("com.apple.keylayout.ABC", ["en", "af", "asa"], "ABC"), "EN")
        XCTAssertEqual(abbreviation("com.apple.keylayout.Russian", ["ru", "bg", "bs_Cyrl"], "Russian"), "RU")
        XCTAssertEqual(abbreviation("x", ["chr"], "Cherokee"), "CHR")
        XCTAssertEqual(abbreviation("x", ["sr-Latn"], "Serbian – Latin"), "SR")
        XCTAssertEqual(abbreviation("x", [], "dvorak"), "D")
        XCTAssertEqual(abbreviation("x", [], ""), "?")
    }

    // 표시 방식에 맞는 글자. 약자가 같으면 무엇이 바뀌었는지 알 수 없어 그 전환만 이름으로 보여 준다.
    func testDisplayTexts() {
        let abc = InputSourceLabel(name: "ABC", abbreviation: "EN")
        let us = InputSourceLabel(name: "U.S.", abbreviation: "EN")
        let korean = InputSourceLabel(name: "2-Set Korean", abbreviation: "한")
        var look = HUDAppearance()
        XCTAssertTrue(look.texts(from: abc, to: korean) == ("ABC", "2-Set Korean"))
        look.display = .abbreviation
        XCTAssertTrue(look.texts(from: abc, to: korean) == ("EN", "한"))
        XCTAssertTrue(look.texts(from: abc, to: us) == ("ABC", "U.S."))
        XCTAssertTrue(look.texts(from: abc, to: nil) == ("EN", nil))  // 바꿀 곳이 없으면 "없음"
    }

    // 약자 배지: 글자가 높이보다 좁으면 좌우 여백을 똑같이 늘려 정사각형 가운데에 둔다. 넓으면 기본 여백(가로로 긴 알약).
    func testBadgeCentersNarrowText() {
        // "한" 30×34pt, 여백 16 → 좌우 18씩, 폭 66 = 높이 66
        XCTAssertEqual(HUD.badgeInset(content: CGSize(width: 30, height: 34), padding: 16), 18)
        // "EN" 46pt는 정사각형보다 넓으므로 기본 여백
        XCTAssertEqual(HUD.badgeInset(content: CGSize(width: 46, height: 34), padding: 16), 16)
        // 폭이 반 포인트로 끝나도(스택이 쓰는 intrinsic 폭 24.5) 여백을 반올림하지 않아야 폭이 높이와 같다.
        let inset = HUD.badgeInset(content: CGSize(width: 24.5, height: 33), padding: 16)
        XCTAssertEqual(24.5 + inset * 2, 33 + 16 * 2)
    }

    // HUD 높이는 가장 큰 글자('변경 후')에 위아래 여백을 더한 값이다. '변경 전'이 보여도 작은 글자에 맞춰 낮아지지 않는다.
    func testHUDHeightFollowsTallestText() {
        XCTAssertEqual(HUD.panelHeight(contentHeights: [24, 24, 33], padding: 16), 65)  // 변경 전 · 화살표 · 변경 후
        XCTAssertEqual(HUD.panelHeight(contentHeights: [33], padding: 16), 65)  // 변경 전을 숨겨도 같은 높이
    }

    // 표시 방식이 생기기 전에 저장한 모양도 그대로 읽고, 표시 방식은 기본(이름)이 된다.
    func testAppearanceWithoutDisplayStillDecodes() {
        let old = #"{"theme":"dracula","size":"large","corners":"pill","bold":true,"showsFrom":false}"#
        let look = HUDAppearance(data: Data(old.utf8))
        XCTAssertEqual(look.theme, .dracula)
        XCTAssertEqual(look.size, .large)
        XCTAssertEqual(look.corners, .pill)
        XCTAssertTrue(look.bold)
        XCTAssertFalse(look.showsFrom)
        XCTAssertEqual(look.display, .name)
    }

    // Caps Lock: 처음 읽은 상태는 기억만 하고, 바뀐 순간에만 새 상태를 돌려준다.
    func testCapsLockTrackerReportsOnlyChanges() {
        var tracker = CapsLockTracker()
        XCTAssertNil(tracker.update(false))  // 시작 상태는 띄우지 않는다
        XCTAssertNil(tracker.update(false))
        XCTAssertEqual(tracker.update(true), true)
        XCTAssertNil(tracker.update(true))  // 0.1초마다 같은 값을 읽어도 한 번만
        XCTAssertEqual(tracker.update(false), false)
        tracker.reset()  // 설정을 껐다 켜면 그때 상태부터 다시 기억한다
        XCTAssertNil(tracker.update(true))
    }

    // Caps Lock HUD 색: 켜짐은 기호=화살표 색·단어=변경 후 색, 꺼짐은 둘 다 변경 전 색. 테마 색을 그대로 빌린다.
    func testCapsLockColorsBorrowThemeColors() throws {
        let dracula = try XCTUnwrap(HUDTheme.dracula.presetColors(.dark))
        XCTAssertTrue(dracula.capsLock(on: true) == (dracula.arrow, dracula.to))
        XCTAssertTrue(dracula.capsLock(on: false) == (dracula.from, dracula.from))
    }

    func testDurationSnapsToHalfSecondsWithinRange() {
        let cases: [(Double, Double)] = [(0.2, 0.5), (-1, 0.5), (0.5, 0.5), (1.2, 1.0), (1.3, 1.5), (2.75, 3.0), (5.0, 5.0), (7, 5.0)]
        for (input, expected) in cases {
            XCTAssertEqual(SettingsWindow.snapped(input), expected, "\(input)")
        }
    }

    // 표시 시간 스테퍼는 0.5–5.0, 0.5 단위이고 끝에서 멈춘다(NSStepper 기본값은 0.5에서 내리면 5.0 쪽으로 넘어간다).
    func testDurationStepperStopsAtEnds() {
        let stepper = SettingsWindow.makeDurationStepper()
        XCTAssertFalse(stepper.valueWraps)
        XCTAssertEqual([stepper.minValue, stepper.maxValue, stepper.increment], [0.5, 5.0, 0.5])
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
    // 사용자 지정은 바꾸는 순간의 모습을 그대로 이어받는다. 어느 테마에서 바꿔도 HUD가 하나도 바뀌지 않아야 한다.
    func testSwitchingToCustomKeepsTheLook() {
        for theme in HUDTheme.presets {
            var look = HUDAppearance()
            look.select(theme)
            let before = HUDMode.allCases.map { look.colors($0) }
            look.select(.custom)
            XCTAssertEqual(HUDMode.allCases.map { look.colors($0) }, before, "\(theme)")
        }
    }

    // 유리는 기본 테마이고, macOS 26 이상이고, 투명도 줄이기가 꺼져 있을 때만 쓴다. 클래식은 언제나 쓰지 않는다.
    func testUsesGlassOnlyForStandardThemeOnSupportedOSWithoutReduceTransparency() {
        for theme in HUDTheme.allCases {
            var look = HUDAppearance()
            look.select(theme)
            for available in [true, false] {
                for reduce in [true, false] {
                    XCTAssertEqual(look.usesGlass(glassAvailable: available, reduceTransparency: reduce),
                                   theme == .standard && available && !reduce, "\(theme) \(available) \(reduce)")
                }
            }
        }
    }

    // 유리는 뒤 배경이 어두우면 안쪽 외관을 다크로 바꾼다. 유리로 그릴 때는 그 안쪽 외관의 색을 써야 글자가 읽힌다.
    // 유리를 쓰지 않으면 시스템 모드를 따른다.
    func testColorModeFollowsGlassContentOnlyWhenUsingGlass() {
        for theme in HUDTheme.allCases {
            var look = HUDAppearance()
            look.select(theme)
            for available in [true, false] {
                for reduce in [true, false] {
                    let glass = look.usesGlass(glassAvailable: available, reduceTransparency: reduce)
                    XCTAssertEqual(look.colorMode(system: .light, glassContent: .dark, glassAvailable: available, reduceTransparency: reduce),
                                   glass ? .dark : .light, "\(theme) \(available) \(reduce)")
                    XCTAssertEqual(look.colorMode(system: .dark, glassContent: .light, glassAvailable: available, reduceTransparency: reduce),
                                   glass ? .light : .dark, "\(theme) \(available) \(reduce)")
                }
            }
        }
    }

    // 클래식은 1.1.0의 기본 모양이라 기본 테마와 같은 색으로 그린다. 투명도 줄이기에서도 기본처럼 불투명 surface다.
    func testClassicHasStandardColors() {
        var look = HUDAppearance()
        look.select(.classic)
        for mode in HUDMode.allCases {
            for reduce in [true, false] {
                XCTAssertEqual(look.colors(mode, reduceTransparency: reduce), HUDAppearance.standard.colors(mode, reduceTransparency: reduce), "\(mode) \(reduce)")
            }
        }
        XCTAssertEqual(look.colors(.dark, reduceTransparency: true).background, RGBA(hex: 0x1c1c1e))
    }

    func testClassicThemeIsSavedAndRead() {
        var look = HUDAppearance()
        look.select(.classic)
        XCTAssertEqual(HUDAppearance(data: look.data).theme, .classic)
        XCTAssertEqual(HUDAppearance(data: Data(#"{"theme":"classic"}"#.utf8)).theme, .classic)
    }

    // 1.1.0에서 저장한 기본 테마는 그대로 기본(macOS 26에서는 유리)으로 읽는다.
    func testStandardThemeFrom110IsKept() {
        let look = HUDAppearance(data: Data(#"{"theme":"standard","size":"large","showsFrom":false}"#.utf8))
        XCTAssertEqual(look.theme, .standard)
        XCTAssertEqual(look.size, .large)
        XCTAssertFalse(look.showsFrom)
    }

    // 1.2.0 개발판에서 저장한 "glass"는 기본으로 읽고, 나머지 설정은 버리지 않는다.
    func testGlassThemeFromDevBuildIsReadAsStandard() {
        let look = HUDAppearance(data: Data(#"{"theme":"glass","size":"large","showsFrom":false}"#.utf8))
        XCTAssertEqual(look.theme, .standard)
        XCTAssertEqual(look.size, .large)
        XCTAssertFalse(look.showsFrom)
    }

    // 클래식에서 사용자 지정으로 바꾸면 기본 테마 색에서 시작한다.
    func testCustomFromClassicStartsFromStandardColors() throws {
        var look = HUDAppearance()
        look.select(.classic)
        look.select(.custom)
        let standard = try XCTUnwrap(HUDTheme.standard.presetColors(.light))
        XCTAssertEqual(look.custom(.light), CustomColors(standard))
    }

    // 사용자 지정은 바꿀 때마다 그때 쓰던 테마에서 이어서 시작한다(예전에 저장한 사용자 지정 색으로 돌아가지 않는다).
    func testCustomContinuesFromCurrentThemeEveryTime() throws {
        var look = HUDAppearance()
        look.select(.custom)  // 기본에서 한 번 바꿔 둔 상태
        look.select(.dracula)
        look.select(.custom)
        let dracula = try XCTUnwrap(HUDTheme.dracula.presetColors(.dark))
        XCTAssertEqual(look.custom(.dark), CustomColors(text: dracula.to, from: dracula.from, arrow: dracula.arrow, background: dracula.background))

        // 사용자 지정에 머무는 동안 고친 색은 남는다.
        var edited = try XCTUnwrap(look.custom(.dark))
        edited.background = RGBA(hex: 0x123456, alpha: 0.5)
        look.setCustom(edited, for: .dark)
        look.select(.custom)
        XCTAssertEqual(look.custom(.dark), edited)
        XCTAssertEqual(HUDAppearance(data: look.data).custom(.dark), edited)

        // 다른 테마를 고르면 다음 사용자 지정은 그 테마에서 시작한다.
        look.select(.gruvbox)
        look.select(.custom)
        XCTAssertEqual(look.custom(.dark)?.background, HUDTheme.gruvbox.presetColors(.dark)?.background)
    }

    func testCustomColorsAreUsedAsIs() throws {
        var look = HUDAppearance()
        look.select(.custom)
        let custom = CustomColors(text: RGBA(hex: 0x112233), from: RGBA(hex: 0x445566), arrow: RGBA(hex: 0xaa0000), background: RGBA(hex: 0xffeedd, alpha: 0.7))
        look.setCustom(custom, for: .light)
        XCTAssertEqual(look.colors(.light), HUDColors(background: custom.background, from: custom.from, arrow: custom.arrow, to: custom.text, blur: 1))
        XCTAssertEqual(look.colors(.light, reduceTransparency: true).background.alpha, 1)
    }

    // 사용자 지정의 배경 불투명도는 덧칠 색과 그 아래 흐림을 함께 조절한다. 0이면 판 없이 글자만 남는다.
    func testCustomOpacityAlsoFadesBlur() throws {
        var look = HUDAppearance()
        XCTAssertEqual(look.colors(.light).blur, 1)  // 프리셋은 흐림을 그대로 깐다
        look.select(.custom)
        var custom = try XCTUnwrap(look.custom(.light))
        // 흐림 = min(1, 불투명도 ÷ 0.55). 기본 테마(0.55)·Dracula 계열(0.92)과 같은 모습이 나오고, 그 아래로 내리면 흐림도 옅어진다.
        for (alpha, blur) in [(0.0, 0.0), (0.275, 0.5), (0.55, 1.0), (0.92, 1.0), (1.0, 1.0)] {
            custom.background = custom.background.withAlpha(alpha)
            look.setCustom(custom, for: .light)
            XCTAssertEqual(look.colors(.light).blur, blur, accuracy: 0.0001, "\(alpha)")
            XCTAssertEqual(look.colors(.light).background.alpha, alpha)
        }
    }

    // 예전에 저장한 사용자 지정(글자·배경만)도 읽는다. 변경 전은 글자색을 흐리게, 화살표는 강조색.
    func testOldCustomColorsStillDecode() throws {
        let old = #"{"theme":"custom","size":"medium","corners":"standard","bold":false,"showsFrom":true,"#
            + #""customLight":{"text":{"red":0,"green":0,"blue":0,"alpha":1},"background":{"red":1,"green":1,"blue":1,"alpha":0.5}}}"#
        let look = HUDAppearance(data: Data(old.utf8))
        XCTAssertEqual(look.theme, .custom)
        let light = try XCTUnwrap(look.custom(.light))
        XCTAssertEqual(light.from, RGBA(hex: 0x000000, alpha: 0.6))
        XCTAssertEqual(light.arrow, RGBA(hex: 0x0a66d6))
        XCTAssertEqual(light.background.alpha, 0.5)
    }

    func testLowContrastWarning() {
        let white = RGBA(hex: 0xffffff), black = RGBA(hex: 0x000000), gray = RGBA(hex: 0x888888)
        XCTAssertTrue(CustomColors(text: RGBA(hex: 0x777777), from: black, arrow: black, background: gray).isLowContrast)
        XCTAssertTrue(CustomColors(text: black, from: RGBA(hex: 0xeeeeee), arrow: black, background: white).isLowContrast)  // 변경 전 글자도 본다
        XCTAssertFalse(CustomColors(text: black, from: black, arrow: black, background: white).isLowContrast)
        // 배경이 거의 투명하면 뒤 화면에 따라 글자가 묻힐 수 있다
        XCTAssertTrue(CustomColors(text: black, from: black, arrow: black, background: white.withAlpha(0.2)).isLowContrast)
    }

    // 이름이 바뀌어 미니 HUD 크기가 달라지면 놓인 자리도 다시 잡아야 한다(설정 창이 열린 채 입력소스를 바꾼 경우).
    func testChipAsksParentToRelayoutWhenItsSizeChanges() {
        let parent = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 100))
        let chip = HUDChip(style: HUDChip.preview)
        parent.addSubview(chip)
        let abc = InputSourceLabel(name: "ABC", abbreviation: "EN")
        chip.set(from: abc, to: abc)
        parent.layoutSubtreeIfNeeded()
        parent.needsLayout = false
        chip.set(from: abc, to: InputSourceLabel(name: "2-Set Korean", abbreviation: "한"))
        XCTAssertTrue(parent.needsLayout)
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
        look.display = .abbreviation
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

    // 배지 위치: 포인터 영역(화살표의 흰 외곽선까지, 끝점에서 (-2, -2)부터 13×19pt) 바깥에 4pt(space-1) 띄운다.
    // AppKit 좌표라 y가 위로 증가한다. 외곽선을 넣어야 위·왼쪽도 오른쪽·아래와 비슷하게 떨어져 보인다.
    func testBadgePlacementAroundPointer() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let badge = CGSize(width: 24, height: 24)
        let origin = { (placement: BadgePlacement, pointer: CGPoint) in placement.origin(size: badge, pointer: pointer, in: screen) }
        let p = CGPoint(x: 500, y: 500)
        XCTAssertEqual(origin(.bottomRight, p), CGPoint(x: 515, y: 455))  // 기본: 끝점에서 오른쪽 15, 아래 21
        XCTAssertEqual(origin(.bottom, p), CGPoint(x: 493, y: 455))  // 영역 가운데에 맞춤(492.5 반올림)
        XCTAssertEqual(origin(.top, p), CGPoint(x: 493, y: 506))  // 외곽선(2) + 간격(4) 위
        XCTAssertEqual(origin(.topLeft, p), CGPoint(x: 470, y: 506))
        XCTAssertEqual(origin(.left, p), CGPoint(x: 470, y: 481))  // 외곽선(2) + 간격(4) 왼쪽, 세로는 영역 가운데(480.5 반올림)
        XCTAssertEqual(origin(.right, p), CGPoint(x: 515, y: 481))
    }

    // 넘친 축만 반대쪽으로 뒤집고, 그래도 넘치면 화면 안으로 밀어 넣는다.
    func testBadgePlacementFlipsAtScreenEdges() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 875)
        let badge = CGSize(width: 24, height: 24)
        XCTAssertEqual(BadgePlacement.bottomRight.origin(size: badge, pointer: CGPoint(x: 1430, y: 500), in: screen), CGPoint(x: 1400, y: 455))  // 오른쪽 끝 → 왼쪽
        XCTAssertEqual(BadgePlacement.bottomRight.origin(size: badge, pointer: CGPoint(x: 500, y: 10), in: screen), CGPoint(x: 515, y: 16))  // 아래 끝 → 위
        XCTAssertEqual(BadgePlacement.topRight.origin(size: badge, pointer: CGPoint(x: 1438, y: 870), in: screen), CGPoint(x: 1408, y: 825))  // 구석은 둘 다
        XCTAssertEqual(BadgePlacement.top.origin(size: badge, pointer: CGPoint(x: 2, y: 500), in: screen), CGPoint(x: 0, y: 506))  // 가운데 축은 밀어 넣기만
    }

    func testBadgePlacementSavedValue() {
        XCTAssertEqual(BadgePlacement(saved: nil), .bottomRight)  // 기본값
        XCTAssertEqual(BadgePlacement(saved: "sideways"), .bottomRight)  // 읽을 수 없는 값
        XCTAssertEqual(BadgePlacement(saved: BadgePlacement.top.rawValue), .top)
        XCTAssertEqual(BadgePlacement.allCases.count, 8)  // 가운데는 없다
    }

    // 배지 크기: HUD 크기와 따로 고르고, 글자 13 · 16 · 21pt에 높이는 글자 × 2.2, 좌우 패딩은 글자 × 0.5.
    func testBadgeSizeMetrics() {
        let metrics = HUDAppearance.Size.allCases.map(CursorBadgeView.metrics)
        XCTAssertEqual(metrics.map(\.font), [13, 16, 21])
        XCTAssertEqual(metrics.map(\.height), [29, 35, 46])
        XCTAssertEqual(metrics.map(\.padding), [7, 8, 11])
        XCTAssertEqual(CursorBadge.size(saved: nil), .medium)  // 기본은 보통
        XCTAssertEqual(CursorBadge.size(saved: "huge"), .medium)
        XCTAssertEqual(CursorBadge.size(saved: "small"), .small)
    }

    // 배지 폭: 글자 + 좌우 패딩이고 높이보다 좁아지지 않는다(한 글자면 원, EN이면 가로로 긴 알약).
    func testBadgeWidthNeverNarrowerThanHeight() {
        XCTAssertEqual(CursorBadgeView.width(text: 7.5, height: 24, padding: 8), 24)
        XCTAssertEqual(CursorBadgeView.width(text: 15.2, height: 24, padding: 8), 32)
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

// 입력 통계. 날짜 계산은 서울 시간대 그레고리력으로 고정한다.
final class StatisticsTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    private func switches(_ count: Double) -> StatsCounts { StatsCounts(switches: count) }

    func testLogAddsToHourAndDay() {
        var log = StatsLog()
        log.add(switches(1), at: date(28, 9, 10), calendar: calendar)
        log.add(switches(2), at: date(28, 9, 50), calendar: calendar)
        log.add(switches(4), at: date(28, 10, 5), calendar: calendar)
        XCTAssertEqual(log.hours.count, 2)
        XCTAssertEqual(log.hours[Int(date(28, 9).timeIntervalSince1970)]?.switches, 3)
        XCTAssertEqual(log.days["2026-10-28"]?.switches, 7)
    }

    // 끝나지 않은 지금 칸은 다 세고, 앞 기간이 칸 중간에서 끝나면 겹친 비율만 센다.
    func testTotalUsesPartOfHourAtEdges() {
        var log = StatsLog()
        log.add(switches(60), at: date(27, 14, 10), calendar: calendar)  // 어제 14시 칸
        log.add(switches(5), at: date(28, 14, 10), calendar: calendar)  // 오늘 14시 칸(진행 중)
        let now = date(28, 14, 30)
        XCTAssertEqual(log.total(from: date(28, 0), to: now, now: now).switches, 5)
        XCTAssertEqual(log.total(from: date(27, 0), to: date(27, 14, 30), now: now).switches, 30, accuracy: 0.001)
    }

    func testPruneKeepsNinetyDaysOfHoursAndAllDays() {
        var log = StatsLog()
        log.add(switches(1), at: date(28, 9).addingTimeInterval(-91 * 86400), calendar: calendar)
        log.add(switches(1), at: date(28, 9).addingTimeInterval(-89 * 86400), calendar: calendar)
        log.prune(now: date(28, 9))
        XCTAssertEqual(log.hours.count, 1)
        XCTAssertEqual(log.days.count, 2)
    }

    func testPeriodRangesCompareSameTimeEarlier() {
        let now = date(28, 16)
        let today = StatsPeriod.today.ranges(now: now, calendar: calendar)
        XCTAssertEqual(today.current, DateInterval(start: date(28, 0), end: now))
        XCTAssertEqual(today.previous, DateInterval(start: date(27, 0), end: date(27, 16)))
        let week = StatsPeriod.week.ranges(now: now, calendar: calendar)
        XCTAssertEqual(week.current.start, date(22, 0))
        XCTAssertEqual(week.previous, DateInterval(start: date(15, 0), end: date(21, 16)))
        let month = StatsPeriod.month.ranges(now: now, calendar: calendar)
        XCTAssertEqual(month.current.start, calendar.date(from: DateComponents(year: 2026, month: 9, day: 29))!)
    }

    func testSlotsAndAxis() {
        let now = date(28, 16)
        let locale = Locale(identifier: "en_US")
        XCTAssertEqual(StatsPeriod.today.slots(now: now, calendar: calendar).count, 24)
        XCTAssertEqual(StatsPeriod.week.slots(now: now, calendar: calendar).count, 7)
        XCTAssertEqual(StatsPeriod.month.slots(now: now, calendar: calendar).count, 30)
        XCTAssertEqual(StatsPeriod.today.axisLabels(now: now, calendar: calendar, locale: locale), ["0", "6", "12", "18", "24"])
        XCTAssertEqual(StatsPeriod.week.axisLabels(now: now, calendar: calendar, locale: locale), ["Thu", "Fri", "Sat", "Sun", "Mon", "Tue", String(localized: "Today")])
        XCTAssertEqual(StatsPeriod.month.axisLabels(now: now, calendar: calendar, locale: locale), ["9/29", String(localized: "Today")])
    }

    func testSummaryBarsAndPeriods() {
        var log = StatsLog()
        log.add(switches(3), at: date(28, 9), calendar: calendar)
        log.add(switches(2), at: date(27, 9), calendar: calendar)
        let today = StatsSummary(log: log, period: .today, now: date(28, 16), calendar: calendar)
        XCTAssertEqual(today.current.switches, 3)
        XCTAssertEqual(today.previous.switches, 2)
        XCTAssertEqual(today.bars[9], 3)
        let week = StatsSummary(log: log, period: .week, now: date(28, 16), calendar: calendar)
        XCTAssertEqual(week.bars.suffix(2), [2, 3])
    }

    func testChangeRules() {
        XCTAssertNil(StatsChange.between(5, 0))  // 앞 기간이 0이면 숨김
        XCTAssertEqual(StatsChange.between(100.5, 100), .same)  // 1% 미만
        XCTAssertEqual(StatsChange.between(118, 100), .up(18))
        XCTAssertEqual(StatsChange.between(97, 100), .down(3))
        XCTAssertEqual(StatsChange.between(0, 100), .down(100))
        // 문구는 실행 언어를 따르므로 화살표와 숫자가 들어가는지만 본다.
        XCTAssertTrue(StatsChange.up(18).text(.today).contains("▲18%"))
        XCTAssertTrue(StatsChange.down(3).text(.month).contains("▼3%"))
        XCTAssertEqual(StatsChange.same.text(.week), String(localized: "Same as previous 7 days"))
    }

    func testBarHeights() {
        XCTAssertEqual(StatsBars.heights([0, 0], height: 48), [0, 0])
        XCTAssertEqual(StatsBars.heights([], height: 48), [])
        XCTAssertEqual(StatsBars.heights([0, 1, 100, 50], height: 48), [0, 2, 48, 24])  // 0이 아닌 칸은 최소 2pt
    }

    func testPointerMeter() {
        var meter = PointerMeter()
        XCTAssertEqual(meter.move(to: .zero, at: 0, millimetersPerPoint: 0.2), StatsCounts())  // 첫 이벤트는 기준점
        let step = meter.move(to: CGPoint(x: 30, y: 40), at: 0.1, millimetersPerPoint: 0.2)
        XCTAssertEqual(step.distance, 10, accuracy: 0.0001)
        XCTAssertEqual(step.movingTime, 0.1, accuracy: 0.0001)
        XCTAssertEqual(step.topSpeed, 0)  // 0.25초가 안 됐다
        let window = meter.move(to: CGPoint(x: 60, y: 80), at: 0.25, millimetersPerPoint: 0.2)
        XCTAssertEqual(window.topSpeed, 20 / 0.25, accuracy: 0.0001)
        let afterIdle = meter.move(to: CGPoint(x: 60, y: 90), at: 2, millimetersPerPoint: 0.2)
        XCTAssertEqual(afterIdle.distance, 2, accuracy: 0.0001)
        XCTAssertEqual(afterIdle.movingTime, 0)  // 멈췄던 시간은 넣지 않는다
    }

    func testPointerConversions() {
        XCTAssertEqual(PointerMeter.millimetersPerPoint(physicalWidth: 300, pointWidth: 1500), 0.2)
        XCTAssertEqual(PointerMeter.millimetersPerPoint(physicalWidth: 0, pointWidth: 1500), 25.4 / 110)
        XCTAssertEqual(PointerMeter.scrollPoints(dx: 3, dy: 4, precise: true), 5)
        XCTAssertEqual(PointerMeter.scrollPoints(dx: 0, dy: 1, precise: false), 10)
    }

    func testClicksAndAverages() {
        XCTAssertEqual(StatsCounts.click(left: true, clickCount: 1).leftClicks, 1)
        XCTAssertEqual(StatsCounts.click(left: true, clickCount: 2).doubleClicks, 1)
        XCTAssertEqual(StatsCounts.click(left: false, clickCount: 1).rightClicks, 1)
        var counts = StatsCounts(distance: 100, movingTime: 4, topSpeed: 30)
        counts.add(StatsCounts(distance: 100, movingTime: 4, topSpeed: 50, leftClicks: 2), fraction: 0.5)
        XCTAssertEqual(counts.distance, 150)
        XCTAssertEqual(counts.topSpeed, 50)  // 최고 속도는 나누지 않는다
        XCTAssertEqual(counts.leftClicks, 1)
        XCTAssertEqual(counts.averageSpeed, 25)
        XCTAssertEqual(StatsCounts().averageSpeed, 0)
    }

    func testFormatsFollowLocale() {
        XCTAssertEqual(StatsFormat.count(1239.6, locale: Locale(identifier: "en_US")), "1,240")
        XCTAssertEqual(StatsFormat.distance(millimeters: 1_330_000, locale: Locale(identifier: "ko_KR")), "1.33km")
        XCTAssertEqual(StatsFormat.distance(millimeters: 113_000, locale: Locale(identifier: "de_DE")), "113 m")
        XCTAssertEqual(StatsFormat.distance(millimeters: 1_609_344, locale: Locale(identifier: "en_US")), "1 mi")
        XCTAssertEqual(StatsFormat.distance(millimeters: 124, locale: Locale(identifier: "en_US")), "4.88 in")
        XCTAssertEqual(StatsFormat.distance(millimeters: 0, locale: Locale(identifier: "de_DE")), "0 mm")
        XCTAssertEqual(StatsFormat.distance(millimeters: 9.996, locale: Locale(identifier: "de_DE")), "1 cm")  // 반올림한 뒤 단위를 고른다
        XCTAssertEqual(StatsFormat.distance(millimeters: 999_600, locale: Locale(identifier: "de_DE")), "1 km")
        XCTAssertEqual(StatsFormat.speed(millimetersPerSecond: 124, locale: Locale(identifier: "de_DE")), "12,4 cm/s")
    }

    // 횟수와 단위는 한 문장이고, 숫자를 크게 칠하려면 숫자가 그대로 들어 있어야 한다.
    func testCountUnitKeepsNumber() {
        XCTAssertTrue(String(localized: "\(1) times").contains(StatsFormat.count(1, locale: .current)))
        XCTAssertTrue(String(localized: "\(1240) times").contains(StatsFormat.count(1240, locale: .current)))  // 1,240
    }

    func testLogRoundTripsThroughJSON() throws {
        var log = StatsLog()
        log.add(StatsCounts(switches: 2, distance: 3.5), at: date(28, 9), calendar: calendar)
        XCTAssertEqual(try JSONDecoder().decode(StatsLog.self, from: JSONEncoder().encode(log)), log)
    }
}

final class ReleaseNotesTests: XCTestCase {
    private let feature = ReleaseNotes.Feature(symbol: "star", title: "T", detail: "D")
    private var notes: [String: [ReleaseNotes.Feature]] { ["1.3.0": [feature], "1.4.0": [feature], "1.10.0": [feature]] }

    private func show(_ current: String, lastSeen: String?, welcome: Bool = true) -> Bool {
        ReleaseNotes.opensAfterUpdate(current: current, lastSeen: lastSeen, didShowWelcome: welcome, notes: notes)
    }

    func testShowsOnceAfterUpgrade() {
        XCTAssertFalse(show("1.3.0", lastSeen: nil, welcome: false))  // 새 설치
        XCTAssertTrue(show("1.3.0", lastSeen: nil))  // 1.2.0 이하에서 올라옴(기록 없음)
        XCTAssertFalse(show("1.3.0", lastSeen: "1.3.0"))  // 다시 실행
        XCTAssertFalse(show("1.3.1", lastSeen: "1.3.0"))  // 노트 없는 버전
        XCTAssertTrue(show("1.4.0", lastSeen: "1.3.0"))
        XCTAssertTrue(show("1.4.0", lastSeen: nil))  // 1.3.0을 건너뜀
        XCTAssertFalse(show("1.3.0", lastSeen: "1.4.0"))  // 다운그레이드
    }

    func testComparesVersionsAsNumbers() {
        XCTAssertTrue(show("1.10.0", lastSeen: "1.9.0"))
        XCTAssertFalse(show("1.4.0", lastSeen: "1.10.0"))
    }

    func testAboutShowsLatestNotesUpToThisVersion() {
        XCTAssertEqual(ReleaseNotes.latest(upTo: "1.3.0", notes: notes)?.version, "1.3.0")
        XCTAssertEqual(ReleaseNotes.latest(upTo: "1.3.1", notes: notes)?.version, "1.3.0")  // PATCH는 1.3.0의 노트
        XCTAssertEqual(ReleaseNotes.latest(upTo: "1.9.0", notes: notes)?.version, "1.4.0")
        XCTAssertEqual(ReleaseNotes.latest(upTo: "1.10.0", notes: notes)?.version, "1.10.0")
        XCTAssertNil(ReleaseNotes.latest(upTo: "1.2.0", notes: notes))  // 노트가 없으면 목록을 숨김
    }

    func testShippedNotesAreShortWithRealSymbols() {
        XCTAssertNotNil(ReleaseNotes.all["1.3.0"])
        for features in ReleaseNotes.all.values {
            XCTAssertTrue((1...3).contains(features.count))
            for feature in features { XCTAssertNotNil(NSImage(systemSymbolName: feature.symbol, accessibilityDescription: nil)) }
        }
    }
}
