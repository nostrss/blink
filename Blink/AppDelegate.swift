import AppKit
import Carbon
import ServiceManagement

@main
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    // MainMenu nib이 없으므로 delegate를 직접 연결한다.
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    static let showOnSwitchKey = "showOnSwitch"
    private static let didShowWelcomeKey = "didShowWelcome"

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let showItem = NSMenuItem(title: String(localized: "Show Input Switch"), action: #selector(toggleShowOnSwitch), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: String(localized: "Launch at Login"), action: #selector(toggleLoginItem), keyEquivalent: "")

    private var tracker = InputSourceTracker()
    private lazy var hud = HUD()
    private lazy var settingsWindow = SettingsWindow()
    private lazy var aboutWindow = AboutWindow()

    private var showOnSwitch: Bool {
        get { UserDefaults.standard.bool(forKey: Self.showOnSwitchKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.showOnSwitchKey) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [Self.showOnSwitchKey: true, HUD.durationKey: 1.0])

        let image = NSImage(named: "MenuBarIcon")
        image?.isTemplate = true
        image?.accessibilityDescription = "Blink"
        statusItem.button?.image = image

        let menu = NSMenu()
        menu.delegate = self
        let settingsItem = NSMenuItem(title: String(localized: "Settings…"), action: #selector(openSettings), keyEquivalent: ",")
        let aboutItem = NSMenuItem(title: String(localized: "About Blink"), action: #selector(openAbout), keyEquivalent: "")
        for item in [showItem, loginItem, settingsItem, aboutItem] {
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: String(localized: "Quit Blink"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        refreshShowState()

        _ = tracker.update(Self.currentInputSourceName())
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(inputSourceChanged),
            name: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )

        if !UserDefaults.standard.bool(forKey: Self.didShowWelcomeKey) {
            UserDefaults.standard.set(true, forKey: Self.didShowWelcomeKey)
            aboutWindow.show(firstLaunch: true)
        }
    }

    // 로그인 항목은 시스템 설정에서도 끌 수 있으므로 저장하지 않고 메뉴를 열 때마다 읽는다.
    func menuWillOpen(_ menu: NSMenu) {
        loginItem.state = LoginItem.isEnabled ? .on : .off
    }

    @objc private func inputSourceChanged() {
        guard let change = tracker.update(Self.currentInputSourceName()) else { return }
        NSLog("입력소스 변경: %@ → %@", change.from, change.to)
        if showOnSwitch { hud.show(from: change.from, to: change.to) }
    }

    private static func currentInputSourceName() -> String? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let ptr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) else { return nil }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }

    @objc private func openSettings() {
        settingsWindow.show()
    }

    @objc private func openAbout() {
        aboutWindow.show(firstLaunch: false)
    }

    @objc private func toggleLoginItem() {
        LoginItem.set(!LoginItem.isEnabled)
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

// 사용자가 켤 때만 등록한다(기본 꺼짐). App Store 심사 가이드라인 2.4.5(iii)가 동의 없는 자동 실행을 금지한다.
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("로그인 항목 %@ 실패: %@", enabled ? "등록" : "해제", error.localizedDescription)
        }
    }
}

extension NSApplication {
    // LSUIElement 앱이라 창을 열 때 직접 앞으로 가져온다. macOS 14부터 activate(ignoringOtherApps:)는 무시된다.
    func activateForWindow() {
        if #available(macOS 14, *) { activate() } else { activate(ignoringOtherApps: true) }
    }
}

// 직전 입력소스 이름을 기억해 실제로 바뀐 경우에만 "변경 전 → 변경 후"를 돌려준다.
// 한 번 전환에 알림이 여러 번 올 수 있어 같은 이름은 무시한다.
struct InputSourceTracker {
    private(set) var last: String?

    mutating func update(_ name: String?) -> (from: String, to: String)? {
        guard let name, name != last else { return nil }
        defer { last = name }
        return last.map { (from: $0, to: name) } ?? (from: "?", to: name)
    }
}
