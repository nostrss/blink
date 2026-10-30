import Foundation

// 정보 창에 보여 줄 버전별 새로운 기능. 버전마다 많아야 3줄, 버그 수정은 쓰지 않는다.
enum ReleaseNotes {
    struct Feature: Equatable {
        let symbol: String
        let title: String
        let detail: String
    }

    // 마지막으로 실행한 버전. 1.3.0부터 저장하므로 그 전에서 올라온 사용자는 값이 없다.
    static let lastSeenVersionKey = "lastSeenVersion"

    static var all: [String: [Feature]] {
        ["1.4.0": [
            Feature(symbol: "cursorarrow.click", title: String(localized: "Badge Where You Click"),
                    detail: String(localized: "Choose “When Clicking” for “Show Badge” in Pointer Badge settings, and the badge appears briefly where you click instead of following the pointer.")),
            Feature(symbol: "keyboard", title: String(localized: "Typing Statistics"),
                    detail: String(localized: "Turn on Typing Statistics in Statistics settings to see your keystrokes and speed by input source and app. Blink counts keys, never what you type.")),
         ],
         "1.3.0": [
            Feature(symbol: "chart.bar.fill", title: String(localized: "Input Statistics"),
                    detail: String(localized: "See today’s input source switches at the top of the menu, and 7 or 30 days in “Statistics…”. Records stay on this Mac.")),
            Feature(symbol: "slider.horizontal.3", title: String(localized: "Tidier Settings"),
                    detail: String(localized: "Settings are grouped into boxes, like System Settings.")),
         ]]
    }

    // 업데이트한 뒤 첫 실행이라 정보 창을 저절로 열지 정한다. 새 설치, 같은 버전, 다운그레이드, 노트가 없는 버전이면 열지 않는다.
    // lastSeen이 없는데 첫 실행 처리를 한 적이 있으면 1.2.0 이하에서 올라온 사용자다.
    static func opensAfterUpdate(current: String, lastSeen: String?, didShowWelcome: Bool, notes: [String: [Feature]]) -> Bool {
        if let lastSeen {
            guard current.compare(lastSeen, options: .numeric) == .orderedDescending else { return false }
        } else if !didShowWelcome {
            return false
        }
        return notes[current] != nil
    }

    // 정보 창에 보여 줄 노트: 지금 버전 이하에서 가장 최근 것. PATCH 버전(1.3.1)이면 1.3.0의 노트다.
    static func latest(upTo current: String, notes: [String: [Feature]]) -> (version: String, features: [Feature])? {
        notes.filter { $0.key.compare(current, options: .numeric) != .orderedDescending }
            .max { $0.key.compare($1.key, options: .numeric) == .orderedAscending }
            .map { ($0.key, $0.value) }
    }
}
