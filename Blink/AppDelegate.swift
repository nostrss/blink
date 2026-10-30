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
    // 첫 실행 여부. 예전 안내 창 시절의 키 이름을 그대로 쓴다.
    private static let didShowWelcomeKey = "didShowWelcome"

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    private var tracker = InputSourceTracker()
    private var capsLock = CapsLockTracker()
    // 'Caps Lock HUD 표시'가 켜져 있는 동안만 돈다. 샌드박스에서 권한 없이 읽을 수 있는 수정키 상태를 0.1초마다 본다.
    private var capsLockTimer: Timer?
    private lazy var hud = HUD()
    private lazy var cursorBadge = CursorBadge()
    // 입력소스가 바뀔 때 열려 있는 창의 이름만 갱신하려고, 처음 열 때 만든다.
    private var settingsWindow: SettingsWindow?
    private lazy var aboutWindow: AboutWindow = {
        let window = AboutWindow()
        window.typingGranted = { [weak self] in self?.statistics.typingGranted ?? false }
        // 메뉴 카드의 켜기와 같다: 켠 뒤 설정 '통계'를 열어 권한 상태가 보이게 한다.
        window.onEnableTyping = { [weak self] in
            self?.statistics.setTyping(true)
            self?.showSettings(.statistics)
        }
        return window
    }()
    private let statistics = StatsRecorder()
    private lazy var statsWindow: StatsWindow = {
        let window = StatsWindow(recorder: statistics, sources: { Self.sourceInfo() })
        window.promo.onEnable = { [weak self] in self?.statistics.setTyping(true) }
        window.promo.onOpenSystemSettings = { SettingsWindow.openInputMonitoringSettings() }
        return window
    }()
    // 메뉴 맨 위 통계 카드와 그 아래 구분선. '통계 모으기'를 끄면 숨긴다.
    private let statsCard = StatsCardView()
    private let statsCardItem = NSMenuItem()
    private let statsCardSeparator = NSMenuItem.separator()
    private var statsCardTimer: Timer?

    // 지금 입력소스 ID. 입력소스가 바뀔 때만 읽는다.
    private var currentSourceID: String?

    private var showOnSwitch: Bool { UserDefaults.standard.bool(forKey: Self.showOnSwitchKey) }

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [Self.showOnSwitchKey: true, HUD.durationKey: 1.0,
                                                  HUD.positionXKey: 0.5, HUD.positionYKey: 0.5, HUD.showCapsLockKey: false,
                                                  CursorBadge.enabledKey: false,
                                                  StatsRecorder.enabledKey: true, StatsRecorder.typingKey: false])

        let image = NSImage(named: "MenuBarIcon")
        image?.isTemplate = true
        image?.accessibilityDescription = "Blink"
        statusItem.button?.image = image

        // 켜고 끄는 설정은 메뉴가 아니라 설정 창에 둔다. 맨 위는 통계 카드(누를 수 없음)다.
        let menu = NSMenu()
        menu.delegate = self
        statsCardItem.view = statsCard
        // 메뉴 카드의 켜기 버튼: 메뉴를 닫고 켠 뒤 설정 '통계'를 열어 권한 상태가 보이게 한다.
        statsCard.promo.onEnable = { [weak self] in
            guard let self else { return }
            self.statusItem.menu?.cancelTracking()
            self.statistics.setTyping(true)
            self.showSettings(.statistics)
        }
        statsCard.promo.onOpenSystemSettings = { [weak self] in
            self?.statusItem.menu?.cancelTracking()
            SettingsWindow.openInputMonitoringSettings()
        }
        menu.addItem(statsCardItem)
        menu.addItem(statsCardSeparator)
        let statsItem = NSMenuItem(title: String(localized: "Statistics…"), action: #selector(openStatistics), keyEquivalent: "")
        let settingsItem = NSMenuItem(title: String(localized: "Settings…"), action: #selector(openSettings), keyEquivalent: "")
        let aboutItem = NSMenuItem(title: String(localized: "About Blink"), action: #selector(openAbout), keyEquivalent: "")
        // macOS 26부터 시스템이 '설정…'·'종료'에 아이콘을 붙이므로, 나머지 항목에도 붙여 모두 맞춘다.
        if #available(macOS 26, *) {
            statsItem.image = NSImage(systemSymbolName: "chart.bar", accessibilityDescription: nil)
            aboutItem.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: nil)
        }
        for item in [statsItem, settingsItem, aboutItem] {
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: String(localized: "Quit Blink"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
        statusItem.menu = menu

        refreshShowState()
        refreshCapsLockWatch()
        currentSourceID = Self.currentInputSourceID()
        statistics.currentSource = { [weak self] in self?.currentSourceID }
        statistics.reload()

        _ = tracker.update(Self.currentInputSource()?.name)
        reloadCursorBadge()
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(inputSourceChanged),
            name: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )

        // 업데이트한 뒤 처음 실행이면 새로운 기능이 있는 정보 창을 한 번 연다. 여는 순간 본 것으로 저장한다.
        let defaults = UserDefaults.standard
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        if ReleaseNotes.opensAfterUpdate(current: version, lastSeen: defaults.string(forKey: ReleaseNotes.lastSeenVersionKey),
                                         didShowWelcome: defaults.bool(forKey: Self.didShowWelcomeKey), notes: ReleaseNotes.all) {
            aboutWindow.show()
        }
        defaults.set(version, forKey: ReleaseNotes.lastSeenVersionKey)

        // 처음 실행하면 안내 창 대신 설정 창 '일반'을 연다.
        if !UserDefaults.standard.bool(forKey: Self.didShowWelcomeKey) {
            UserDefaults.standard.set(true, forKey: Self.didShowWelcomeKey)
            openSettings()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        statistics.save()
    }

    // 메뉴를 열 때 통계 카드를 새로 읽는다.
    func menuNeedsUpdate(_ menu: NSMenu) {
        statsCardItem.isHidden = !statistics.isEnabled
        statsCardSeparator.isHidden = !statistics.isEnabled
        reloadStatsCard()
    }

    // 열려 있는 동안은 통계 창과 같이 2초마다 새로 읽는다. 메뉴를 추적하는 동안에도 돌도록 common 모드에 건다.
    func menuWillOpen(_ menu: NSMenu) {
        guard statistics.isEnabled else { return }
        let timer = Timer(timeInterval: StatsWindow.refreshInterval, repeats: true) { [weak self] _ in self?.reloadStatsCard() }
        RunLoop.main.add(timer, forMode: .common)
        statsCardTimer = timer
    }

    func menuDidClose(_ menu: NSMenu) {
        statsCardTimer?.invalidate()
        statsCardTimer = nil
    }

    private func reloadStatsCard() {
        if statistics.isEnabled { statsCard.reload(statistics.snapshot, typing: statistics.typingState, sources: Self.sourceInfo()) }
    }

    @objc private func inputSourceChanged() {
        currentSourceID = Self.currentInputSourceID()  // 타이핑 통계는 키마다 묻지 않고 이 값을 쓴다
        guard let change = tracker.update(Self.currentInputSource()?.name) else { return }
        NSLog("입력소스 변경: %@ → %@", change.from, change.to)
        statistics.countSwitch()  // HUD를 꺼도 센다
        if showOnSwitch { hud.show(from: Self.label(named: change.from), to: Self.label(named: change.to)) }
        cursorBadge.update(Self.label(named: change.to))
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

    // 켜진 입력소스 ID → 이름·첫 언어. 통계의 입력소스 이름, 전환 이름(한/영·입력소스), WPM을 정할 때 쓴다.
    private static func sourceInfo() -> [String: InputSourceInfo] {
        let filter = [kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource,
                      kTISPropertyInputSourceIsSelectCapable: true] as CFDictionary
        guard let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource] else { return [:] }
        var result: [String: InputSourceInfo] = [:]
        for source in list {
            guard let id = string(source, kTISPropertyInputSourceID), let name = string(source, kTISPropertyLocalizedName) else { continue }
            let languages = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages)
                .flatMap { Unmanaged<AnyObject>.fromOpaque($0).takeUnretainedValue() as? [String] }
            result[id] = InputSourceInfo(name: name, language: languages?.first)
        }
        return result
    }

    private static func string(_ source: TISInputSource, _ key: CFString) -> String? {
        TISGetInputSourceProperty(source, key).map { Unmanaged<CFString>.fromOpaque($0).takeUnretainedValue() as String }
    }

    private static func currentInputSourceID() -> String? {
        TISCopyCurrentKeyboardInputSource().flatMap { string($0.takeRetainedValue(), kTISPropertyInputSourceID) }
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
        showSettings(.general)
    }

    private func showSettings(_ pane: SettingsWindow.Pane) {
        if settingsWindow == nil {
            settingsWindow = SettingsWindow(
                onShowChanged: { [weak self] in self?.refreshShowState() },
                onCapsLockChanged: { [weak self] in self?.capsLockSettingChanged() },
                onPointerChanged: { [weak self] in self?.reloadCursorBadge() },
                onStatisticsChanged: { [weak self] in self?.statistics.reload() },
                onClearStatistics: { [weak self] in self?.statistics.clear() },
                onTypingChanged: { [weak self] on in self?.statistics.setTyping(on) },
                preview: { [weak self] position in
                    guard let self else { return }
                    let names = self.sampleNames()
                    self.hud.show(from: names.from, to: names.to, at: position)
                    self.cursorBadge.reloadLook()  // '모양'을 바꾸면 포인터 배지도 따라간다
                },
                sampleNames: { [weak self] in self?.sampleNames() ?? (from: InputSourceLabel(name: "", abbreviation: ""), to: nil) })
        }
        settingsWindow?.show(pane)
    }

    @objc private func openStatistics() {
        statsWindow.show()
    }

    @objc private func openAbout() {
        aboutWindow.show()
    }

    private func reloadCursorBadge() {
        cursorBadge.reload(showing: Self.currentInputSource() ?? Self.label(named: tracker.last ?? ""))
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
