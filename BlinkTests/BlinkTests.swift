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
        XCTAssertEqual(HUD.panelWidth(fitting: 300, from: 60, ellipsis: 20), 300)
        // 넘치면 480pt로 줄인다('변경 전' 말줄임)
        XCTAssertEqual(HUD.panelWidth(fitting: 600, from: 300, ellipsis: 20), 480)
        // '변경 후'만으로 480pt를 넘으면 '변경 전'을 "…"만 남기고 넓힌다
        XCTAssertEqual(HUD.panelWidth(fitting: 700, from: 100, ellipsis: 20), 620)
    }
}
