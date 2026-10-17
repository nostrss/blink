import AppKit
import Carbon
import ServiceManagement

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    // MainMenu nib이 없으므로 delegate를 직접 연결한다.
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    static let showOnSwitchKey = "showOnSwitch"
    // 첫 실행 여부. 예전 안내 창 시절의 키 이름을 그대로 쓴다.
    private static let didShowWelcomeKey = "didShowWelcome"

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    private var tracker = InputSourceTracker()
    private var lastChange: (from: String, to: String)?
    private lazy var hud = HUD()
    private lazy var settingsWindow = SettingsWindow(
        onShowChanged: { [weak self] in self?.refreshShowState() },
        preview: { [weak self] position in
            guard let self else { return }
            let names = self.sampleNames()
            self.hud.show(from: names.from, to: names.to, at: position)
        },
        sampleNames: { [weak self] in self?.sampleNames() ?? (from: "", to: "") })
    private lazy var aboutWindow = AboutWindow()

    private var showOnSwitch: Bool { UserDefaults.standard.bool(forKey: Self.showOnSwitchKey) }

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [Self.showOnSwitchKey: true, HUD.durationKey: 1.0,
                                                  HUD.positionXKey: 0.5, HUD.positionYKey: 0.5])

        let image = NSImage(named: "MenuBarIcon")
        image?.isTemplate = true
        image?.accessibilityDescription = "Blink"
        statusItem.button?.image = image

        // 켜고 끄는 설정은 메뉴가 아니라 설정 창 '일반'에 둔다.
        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: String(localized: "Settings…"), action: #selector(openSettings), keyEquivalent: ",")
        let aboutItem = NSMenuItem(title: String(localized: "About Blink"), action: #selector(openAbout), keyEquivalent: "")
        for item in [settingsItem, aboutItem] {
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

        // 처음 실행하면 안내 창 대신 설정 창 '일반'을 연다.
        if !UserDefaults.standard.bool(forKey: Self.didShowWelcomeKey) {
            UserDefaults.standard.set(true, forKey: Self.didShowWelcomeKey)
            settingsWindow.show()
        }
    }

    @objc private func inputSourceChanged() {
        guard let change = tracker.update(Self.currentInputSourceName()) else { return }
        NSLog("입력소스 변경: %@ → %@", change.from, change.to)
        lastChange = change
        if showOnSwitch { hud.show(from: change.from, to: change.to) }
    }

    private static func currentInputSourceName() -> String? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let ptr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) else { return nil }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }

    // 위치를 고를 때 보여 줄 이름: 직전 전환, 아직 없으면 현재 입력소스 이름.
    private func sampleNames() -> (from: String, to: String) {
        let current = tracker.last ?? "ABC"
        return lastChange ?? (from: current, to: current)
    }

    @objc private func openSettings() {
        settingsWindow.show()
    }

    @objc private func openAbout() {
        aboutWindow.show()
    }

    private func refreshShowState() {
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
