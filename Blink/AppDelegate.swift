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
    private var capsLock = CapsLockTracker()
    // 'Caps Lock HUD 표시'가 켜져 있는 동안만 돈다. 샌드박스에서 권한 없이 읽을 수 있는 수정키 상태를 0.1초마다 본다.
    private var capsLockTimer: Timer?
    private lazy var hud = HUD()
    // 입력소스가 바뀔 때 열려 있는 창의 이름만 갱신하려고, 처음 열 때 만든다.
    private var settingsWindow: SettingsWindow?
    private lazy var aboutWindow = AboutWindow()

    private var showOnSwitch: Bool { UserDefaults.standard.bool(forKey: Self.showOnSwitchKey) }

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [Self.showOnSwitchKey: true, HUD.durationKey: 1.0,
                                                  HUD.positionXKey: 0.5, HUD.positionYKey: 0.5, HUD.showCapsLockKey: false])

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
        refreshCapsLockWatch()

        _ = tracker.update(Self.currentInputSource()?.name)
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
            openSettings()
        }
    }

    @objc private func inputSourceChanged() {
        guard let change = tracker.update(Self.currentInputSource()?.name) else { return }
        NSLog("입력소스 변경: %@ → %@", change.from, change.to)
        if showOnSwitch { hud.show(from: Self.label(named: change.from), to: Self.label(named: change.to)) }
        settingsWindow?.reloadNames()
    }

    private static func currentInputSource() -> InputSourceLabel? {
        TISCopyCurrentKeyboardInputSource().flatMap { label(of: $0.takeRetainedValue()) }
    }

    // 키보드 설정에서 켜 둔, 고를 수 있는 입력소스(입력기 자체가 아니라 그 안의 입력 방식). 읽기만 하므로 샌드박스에서도 쓸 수 있다.
    private static func enabledInputSources() -> [InputSourceLabel] {
        let filter = [kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource,
                      kTISPropertyInputSourceIsSelectCapable: true] as CFDictionary
        guard let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource] else { return [] }
        var labels: [InputSourceLabel] = []
        for label in list.compactMap(label(of:)) where !labels.contains(where: { $0.name == label.name }) { labels.append(label) }
        return labels
    }

    // 추적기는 이름만 기억하므로, 약자는 켜진 목록에서 같은 이름을 찾아 얻는다. 목록에서 빠졌으면 이름으로 만든다.
    private static func label(named name: String) -> InputSourceLabel {
        enabledInputSources().first { $0.name == name }
            ?? InputSourceLabel(name: name, abbreviation: InputSourceLabel.abbreviation(id: "", languages: [], name: name))
    }

    private static func label(of source: TISInputSource) -> InputSourceLabel? {
        func property<T>(_ key: CFString) -> T? {
            TISGetInputSourceProperty(source, key).flatMap { Unmanaged<AnyObject>.fromOpaque($0).takeUnretainedValue() as? T }
        }
        guard let name: String = property(kTISPropertyLocalizedName) else { return nil }
        let abbreviation = InputSourceLabel.abbreviation(id: property(kTISPropertyInputSourceID) ?? "",
                                                         languages: property(kTISPropertyInputSourceLanguages) ?? [], name: name)
        return InputSourceLabel(name: name, abbreviation: abbreviation)
    }

    // 위치를 고를 때 보여 줄 입력소스: 왼쪽은 현재, 오른쪽은 다음에 바뀔 입력소스(없으면 nil = "없음").
    private func sampleNames() -> (from: InputSourceLabel, to: InputSourceLabel?) {
        let current = Self.currentInputSource() ?? Self.label(named: tracker.last ?? "")
        let next = InputSourceTracker.next(current: current.name, previous: tracker.previous, enabled: Self.enabledInputSources().map(\.name))
        return (current, next.map(Self.label(named:)))
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindow(
                onShowChanged: { [weak self] in self?.refreshShowState() },
                onCapsLockChanged: { [weak self] in self?.capsLockSettingChanged() },
                preview: { [weak self] position in
                    guard let self else { return }
                    let names = self.sampleNames()
                    self.hud.show(from: names.from, to: names.to, at: position)
                },
                sampleNames: { [weak self] in self?.sampleNames() ?? (from: InputSourceLabel(name: "", abbreviation: ""), to: nil) })
        }
        settingsWindow?.show()
    }

    @objc private func openAbout() {
        aboutWindow.show()
    }

    private func refreshShowState() {
        statusItem.button?.appearsDisabled = !showOnSwitch
    }

    // 켜는 순간 실제 화면에 "⇪ 켜짐"을 한 번 띄워 어떻게 보이는지 알려 준다.
    private func capsLockSettingChanged() {
        refreshCapsLockWatch()
        if capsLockTimer != nil { hud.showCapsLock(true) }
    }

    private func refreshCapsLockWatch() {
        guard UserDefaults.standard.bool(forKey: HUD.showCapsLockKey) else {
            capsLockTimer?.invalidate()
            capsLockTimer = nil
            return
        }
        guard capsLockTimer == nil else { return }
        capsLock.reset()
        _ = capsLock.update(NSEvent.modifierFlags.contains(.capsLock))  // 켤 때의 상태는 기억만 한다
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let on = self.capsLock.update(NSEvent.modifierFlags.contains(.capsLock)) else { return }
            self.hud.showCapsLock(on)
        }
        RunLoop.main.add(timer, forMode: .common)  // 메뉴를 여는 동안에도 놓치지 않는다
        capsLockTimer = timer
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

// HUD에 쓰는 입력소스의 두 표기. 표시 방식(HUDAppearance.display)에 따라 하나를 고른다.
struct InputSourceLabel: Equatable {
    var name: String
    var abbreviation: String

    // 약자. 일본어는 언어가 모두 ja라 입력 모드(ID 끝부분)로 나누고, 한·중은 언어로 정한다.
    // 그 밖은 첫 언어 코드를 대문자로(en → EN), 언어 정보가 없으면 이름 첫 글자.
    static func abbreviation(id: String, languages: [String], name: String) -> String {
        guard let language = languages.first else { return name.first.map { String($0).uppercased() } ?? "?" }
        switch language {
        case "ja":
            if id.hasSuffix(".HalfWidthKana") { return "ｱ" }
            if id.hasSuffix(".Katakana") { return "ア" }
            if id.hasSuffix(".FullWidthRoman") { return "Ａ" }
            return "あ"
        case "ko": return "한"
        case "zh-Hans": return "简"
        case "zh-Hant": return "繁"
        default: return String(language.prefix { $0 != "-" && $0 != "_" }).uppercased()
        }
    }
}

// Caps Lock 상태를 0.1초마다 읽은 값에서, 실제로 바뀐 순간에만 새 상태를 돌려준다.
// 처음 읽은 값(앱을 켜거나 설정을 켤 때)은 기억만 한다.
struct CapsLockTracker {
    private var last: Bool?

    mutating func update(_ on: Bool) -> Bool? {
        defer { last = on }
        return last.map { $0 == on ? nil : on } ?? nil
    }

    mutating func reset() { last = nil }
}

// 직전 입력소스 이름을 기억해 실제로 바뀐 경우에만 "변경 전 → 변경 후"를 돌려준다.
// 한 번 전환에 알림이 여러 번 올 수 있어 같은 이름은 무시한다.
struct InputSourceTracker {
    private(set) var last: String?
    // 지금 입력소스 바로 전에 쓰던 것. 시작한 뒤 아직 전환이 없으면 nil.
    private(set) var previous: String?

    mutating func update(_ name: String?) -> (from: String, to: String)? {
        guard let name, name != last else { return nil }
        defer { previous = last; last = name }
        return last.map { (from: $0, to: name) } ?? (from: "?", to: name)
    }

    // 다음에 바뀔 입력소스. ⌃Space 한 번이나 한/영 키는 직전에 쓰던 것으로 돌아가므로 그것을 먼저 고르고,
    // 없거나 목록에서 빠졌으면 켜진 목록에서 현재가 아닌 첫 번째를 고른다. 바꿀 곳이 없으면 nil.
    // enabled가 비어 있으면(목록을 못 읽음) 직전 것을 그대로 믿는다.
    static func next(current: String, previous: String?, enabled: [String]) -> String? {
        if let previous, previous != current, enabled.isEmpty || enabled.contains(previous) { return previous }
        return enabled.first { $0 != current }
    }
}
