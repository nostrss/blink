import AppKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    // MainMenu nib이 없으므로 delegate를 직접 연결한다.
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    private static let showOnSwitchKey = "showOnSwitch"

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let showItem = NSMenuItem(title: "언어 전환 표시", action: #selector(toggleShowOnSwitch), keyEquivalent: "")

    private var showOnSwitch: Bool {
        get { UserDefaults.standard.bool(forKey: Self.showOnSwitchKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.showOnSwitchKey) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [Self.showOnSwitchKey: true])

        let image = NSImage(named: "MenuBarIcon")
        image?.isTemplate = true
        image?.accessibilityDescription = "Blink"
        statusItem.button?.image = image

        showItem.target = self
        let menu = NSMenu()
        menu.addItem(showItem)
        // action이 없는 항목은 NSMenu가 비활성으로 표시한다. 로그인 항목은 5단계, 설정은 4단계, 정보는 5단계에서 연결.
        menu.addItem(NSMenuItem(title: "로그인 시 실행", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "설정…", action: nil, keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "정보…", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Blink 종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        refreshShowState()
    }

    @objc private func toggleShowOnSwitch() {
        showOnSwitch.toggle()
        refreshShowState()
    }

    private func refreshShowState() {
        showItem.state = showOnSwitch ? .on : .off
        statusItem.button?.appearsDisabled = !showOnSwitch
    }
}
