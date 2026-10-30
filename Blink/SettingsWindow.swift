import AppKit

// 메뉴 "설정…"으로 여는 창. 왼쪽 사이드바에서 항목을 고르면 오른쪽에 그 항목의 설정이 나온다.
// 저장 버튼 없이 바로 적용한다. 새 설정은 사이드바에 항목을 추가해서 넣는다.
final class SettingsWindow: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSToolbarDelegate {
    private static let range = 0.5...5.0
    private static let step = 0.5

    enum Pane: CaseIterable {
        case general, hudShow, position, appearance, pointer, statistics

        var title: String {
            switch self {
            case .general: String(localized: "General")
            case .hudShow: String(localized: "Display")
            case .position: String(localized: "Position")
            case .appearance: String(localized: "Appearance")
            case .pointer: String(localized: "Pointer Badge")
            case .statistics: String(localized: "Statistics")
            }
        }

        // 항목이 둘 이상인 기능의 그룹 머리글. 그 아래 항목은 들여 쓴다. 페이지 제목은 항목 이름만 쓴다(Finder·시스템 설정과 같음).
        var group: String? {
            switch self {
            case .hudShow, .position, .appearance: String(localized: "Input Source HUD")
            default: nil
            }
        }
    }

    // 사이드바 줄. 머리글은 누를 수 없다.
    enum SidebarRow: Equatable {
        case header(String)
        case pane(Pane)
    }

    static var sidebarRows: [SidebarRow] {
        var rows: [SidebarRow] = []
        for pane in Pane.allCases {
            if let group = pane.group, !rows.contains(.header(group)) { rows.append(.header(group)) }
            rows.append(.pane(pane))
        }
        return rows
    }

    private let window = ClosableWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 440),
                                        styleMask: [.titled, .closable, .resizable, .fullSizeContentView], backing: .buffered, defer: true)
    private let split = NSSplitViewController()
    private let sidebar = NSTableView()
    private let detail = NSView()
    private lazy var panes: [Pane: NSView] = [.general: makeGeneralPane(), .hudShow: makeHUDShowPane(), .position: positionPane, .appearance: appearancePane, .pointer: pointerPane,
                                                    .statistics: makeStatisticsPane()]
    private let positionPane: PositionPane
    private let appearancePane: AppearancePane
    private let pointerPane: PointerPane

    private let showSwitch = NSSwitch()
    private let capsLockSwitch = NSSwitch()
    private let loginSwitch = NSSwitch()
    private let statisticsSwitch = NSSwitch()
    private let typingSwitch = NSSwitch()
    // '통계'의 상자와 안내. 모으기·타이핑·권한 상태에 따라 줄이 바뀌어 읽을 때마다 새로 채운다.
    private let statisticsContent = NSStackView()
    private let field = NSTextField()
    private let stepper = SettingsWindow.makeDurationStepper()
    private let onShowChanged: () -> Void
    private let onCapsLockChanged: () -> Void
    private let onStatisticsChanged: () -> Void
    private let onClearStatistics: () -> Void
    private let onTypingChanged: (Bool) -> Void
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 1
        return f
    }()

    // onShowChanged: '언어 전환 HUD 표시'를 바꾼 직후(메뉴바 아이콘 갱신용). onCapsLockChanged: 'Caps Lock HUD 표시'를 바꾼 직후
    // onPointerChanged: '포인터' 설정을 바꾼 직후(실제 포인터 배지를 다시 읽게 한다).
    // onStatisticsChanged: '통계 모으기'를 바꾼 직후. onClearStatistics: '모두 지우기…'를 확인한 뒤.
    // preview: 위치·모양을 고르는 동안 실제 화면에 HUD를 띄운다. sampleNames: 미니 HUD와 미리보기에 쓸 이름
    init(onShowChanged: @escaping () -> Void, onCapsLockChanged: @escaping () -> Void, onPointerChanged: @escaping () -> Void,
         onStatisticsChanged: @escaping () -> Void, onClearStatistics: @escaping () -> Void, onTypingChanged: @escaping (Bool) -> Void,
         preview: @escaping (HUDPosition) -> Void,
         sampleNames: @escaping () -> (from: InputSourceLabel, to: InputSourceLabel?)) {
        self.onShowChanged = onShowChanged
        self.onCapsLockChanged = onCapsLockChanged
        self.onStatisticsChanged = onStatisticsChanged
        self.onClearStatistics = onClearStatistics
        self.onTypingChanged = onTypingChanged
        positionPane = PositionPane(preview: preview, sampleNames: sampleNames)
        appearancePane = AppearancePane(preview: { preview(HUD.savedPosition) }, sampleNames: sampleNames)
        pointerPane = PointerPane(onChange: onPointerChanged, sampleNames: sampleNames)
        super.init()
        window.isReleasedWhenClosed = false
        window.backgroundColor = Tokens.surface

        sidebar.style = .sourceList
        sidebar.rowSizeStyle = .custom
        sidebar.rowHeight = 28  // row-sidebar
        sidebar.allowsEmptySelection = false  // 빈 곳을 눌러도 고른 항목을 유지한다
        sidebar.headerView = nil
        sidebar.addTableColumn(NSTableColumn(identifier: .init("pane")))
        sidebar.dataSource = self
        sidebar.delegate = self
        let scroll = NSScrollView()
        scroll.documentView = sidebar
        scroll.drawsBackground = false
        let sidebarController = NSViewController()
        sidebarController.view = scroll
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarController)
        sidebarItem.canCollapse = false
        sidebarItem.minimumThickness = 180
        sidebarItem.maximumThickness = 180

        let detailController = NSViewController()
        detailController.view = detail
        let detailItem = NSSplitViewItem(viewController: detailController)
        split.addSplitViewItem(sidebarItem)
        split.addSplitViewItem(detailItem)
        split.view.frame = NSRect(x: 0, y: 0, width: 620, height: 440)
        window.contentViewController = split

        // 고른 항목 이름을 사이드바 오른쪽 제목 자리에 둔다(시스템 설정과 같은 배치).
        let toolbar = NSToolbar(identifier: "settings")
        toolbar.delegate = self
        window.toolbar = toolbar
        window.toolbarStyle = .unified
        // 툴바 재질의 띠와 구분선 없이 제목 자리도 내용과 같은 배경으로 둔다(시스템 설정과 같은 모양).
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.setContentSize(NSSize(width: 620, height: 440))
        // 이보다 작으면 도움말이 잘린다. 늘린 만큼은 내용 영역이 가져가고(사이드바는 180 고정), 마지막 크기·자리를 기억한다.
        window.contentMinSize = NSSize(width: 620, height: 440)
        if !window.setFrameUsingName("Settings") {
            // 처음 열 때는 '모양'의 사용자 지정 색 줄까지 스크롤 없이 들어가는 높이로 연다. 화면보다 크면 화면에 맞춘다.
            let titleBar = window.frame.height - window.contentLayoutRect.height
            let ideal = max(appearancePane.fullHeight(width: 620 - 180) + titleBar, window.frame.height)
            let limit = (window.screen ?? NSScreen.main)?.visibleFrame.height ?? ideal
            window.setFrame(NSRect(origin: window.frame.origin, size: NSSize(width: window.frame.width, height: min(ideal, limit))), display: false)
            window.center()
        }
        window.setFrameAutosaveName("Settings")

        // 로그인 항목은 시스템 설정에서도 바뀌므로 창이 앞으로 올 때마다 다시 읽는다.
        NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main) { [weak self] _ in
            self?.loginSwitch.state = LoginItem.isEnabled ? .on : .off
            self?.reloadStatistics()
        }
        // 시스템 설정에서 입력 모니터링 권한을 허용하면 권한 줄을 바로 고친다.
        NotificationCenter.default.addObserver(forName: StatsRecorder.typingStateChanged, object: nil, queue: .main) { [weak self] _ in
            self?.reloadStatistics()
        }
    }

    func show(_ pane: Pane = .general) {
        select(pane)
        if let row = Self.sidebarRows.firstIndex(of: .pane(pane)) { sidebar.selectRowIndexes([row], byExtendingSelection: false) }
        showSwitch.state = UserDefaults.standard.bool(forKey: AppDelegate.showOnSwitchKey) ? .on : .off
        capsLockSwitch.state = UserDefaults.standard.bool(forKey: HUD.showCapsLockKey) ? .on : .off
        loginSwitch.state = LoginItem.isEnabled ? .on : .off
        reloadStatistics()
        apply(UserDefaults.standard.double(forKey: HUD.durationKey))
        NSApp.activateForWindow()
        window.makeKeyAndOrderFront(nil)
    }

    // 창이 열려 있는 동안 입력소스가 바뀌면 미니 HUD 이름을 맞춘다.
    func reloadNames() {
        positionPane.reloadNames()
        appearancePane.reloadNames()
        pointerPane.reloadNames()
    }

    private func select(_ pane: Pane) {
        window.title = pane.title
        detail.subviews.forEach { $0.removeFromSuperview() }
        // 항목을 열 때마다 저장된 값으로 맞춘다('모양'에서 바꾼 모양이 '위치'의 미니 HUD에 보이도록).
        if pane == .position { positionPane.reload() }
        if pane == .appearance { appearancePane.reload() }
        if pane == .pointer { pointerPane.reload() }
        let view = panes[pane]!
        view.translatesAutoresizingMaskIntoConstraints = false
        detail.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: detail.safeAreaLayoutGuide.topAnchor),
            view.leadingAnchor.constraint(equalTo: detail.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: detail.trailingAnchor),
            // 스크롤하는 항목은 창 높이를 채운다.
            view is NSScrollView ? view.bottomAnchor.constraint(equalTo: detail.bottomAnchor) : view.bottomAnchor.constraint(lessThanOrEqualTo: detail.bottomAnchor),
        ])
    }

    // MARK: 사이드바

    func numberOfRows(in tableView: NSTableView) -> Int { Self.sidebarRows.count }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        if case .pane = Self.sidebarRows[row] { return true }
        return false
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = NSTableCellView()
        let label: NSTextField
        var indent: CGFloat = 8  // space-2
        switch Self.sidebarRows[row] {
        case .header(let title):
            label = NSTextField(labelWithString: title)
            label.font = .systemFont(ofSize: 11, weight: .semibold)
            label.textColor = Tokens.muted
        case .pane(let pane):
            label = NSTextField(labelWithString: pane.title)
            label.font = .systemFont(ofSize: 13)  // body
            if pane.group != nil { indent = 20 }
        }
        label.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(label)
        cell.textField = label
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: indent),
            label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard Self.sidebarRows.indices.contains(sidebar.selectedRow), case .pane(let pane) = Self.sidebarRows[sidebar.selectedRow] else { return }
        select(pane)
    }

    // 사이드바 위 제목이 내용 영역 위로 오도록 사이드바 경계에 맞춘다.
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { [.sidebarTrackingSeparator] }
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { [.sidebarTrackingSeparator] }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        NSTrackingSeparatorToolbarItem(identifier: itemIdentifier, splitView: split.splitView, dividerIndex: 0)
    }

    // MARK: 일반

    private func makeGeneralPane() -> NSView {
        let body = NSFont.systemFont(ofSize: 13)  // body
        for toggle in [showSwitch, capsLockSwitch, loginSwitch] {
            toggle.controlSize = .small
            toggle.target = self
        }
        showSwitch.action = #selector(showChanged)
        capsLockSwitch.action = #selector(capsLockChanged)
        loginSwitch.action = #selector(loginChanged)
        let loginRow = Self.row(String(localized: "Launch at Login"), [loginSwitch])

        // 값은 스테퍼로만 바꾼다. 입력란은 지금 값을 보여 주기만 한다.
        field.font = body
        field.alignment = .right
        field.isEditable = false
        field.isSelectable = false
        field.widthAnchor.constraint(equalToConstant: 56).isActive = true
        stepper.target = self
        stepper.action = #selector(stepperChanged)
        let unit = NSTextField(labelWithString: String(localized: "sec"))
        unit.font = body
        unit.textColor = Tokens.ink
        let durationRow = Self.row(String(localized: "Display Time"), [field, stepper, unit])
        stepper.setAccessibilityLabel(String(localized: "Display Time"))  // 입력란은 보여 주기만 하므로 VoiceOver가 조절할 곳은 스테퍼다

        let durationGroup = Self.group([durationRow])
        let column = Self.column([Self.group([loginRow]), durationGroup, Self.caption(String(localized: "Display time is shared by the input source HUD and the pointer badge."))])
        column.setCustomSpacing(6, after: durationGroup)  // 도움말은 상자 바로 아래
        return column
    }

    // MARK: 입력소스 HUD › 표시

    private func makeHUDShowPane() -> NSView {
        let group = Self.group([Self.row(String(localized: "Show When Input Source Changes"), [showSwitch]),
                                Self.row(String(localized: "Show When Caps Lock Changes"), [capsLockSwitch])])
        let column = Self.column([group, Self.caption(String(localized: "When Caps Lock changes, the HUD shows “⇪ On” or “⇪ Off”."))])
        column.setCustomSpacing(6, after: group)
        return column
    }

    // MARK: 통계

    private func makeStatisticsPane() -> NSView {
        for toggle in [statisticsSwitch, typingSwitch] {
            toggle.controlSize = .small
            toggle.target = self
        }
        statisticsSwitch.action = #selector(statisticsChanged)
        typingSwitch.action = #selector(typingChanged)
        statisticsContent.orientation = .vertical
        statisticsContent.alignment = .leading
        statisticsContent.spacing = 16  // space-3
        statisticsContent.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)  // space-3
        reloadStatistics()
        return statisticsContent
    }

    // 맨 위 상자: 통계 모으기, (모으는 동안) 타이핑 통계와 입력 모니터링 권한 줄. 권한 줄은 켰거나 권한이 남아 있을 때만 둔다.
    private func reloadStatistics() {
        let defaults = UserDefaults.standard
        let collecting = defaults.bool(forKey: StatsRecorder.enabledKey)
        let typing = defaults.bool(forKey: StatsRecorder.typingKey)
        let granted = CGPreflightListenEventAccess()
        statisticsSwitch.state = collecting ? .on : .off
        typingSwitch.state = typing ? .on : .off
        var rows = [Self.row(String(localized: "Collect Statistics"), [statisticsSwitch])]
        var note = String(localized: "Blink counts only input source switches and pointer usage, never what you type. Statistics never leave this Mac.")
        if collecting {
            rows.append(Self.row(String(localized: "Typing Statistics"), [typingSwitch]))
            if typing || granted { rows.append(permissionRow(typing: typing, granted: granted)) }
            if typing { note = String(localized: "Blink counts only how many keys you press and the input source and app at that moment, never which keys. Statistics never leave this Mac.") }
            else if granted { note = String(localized: "Typing statistics are off, so keystrokes aren’t counted. The permission stays in System Settings; turn off Blink there if you don’t need it.") }
        }
        let clear = NSButton(title: String(localized: "Clear All…"), target: self, action: #selector(clearStatistics))
        clear.controlSize = .small
        let group = Self.group(rows)
        let views = [group, Self.group([Self.row(String(localized: "History"), [clear])]), Self.caption(note)]
        statisticsContent.setViews(views, in: .leading)
        for view in views { view.widthAnchor.constraint(equalTo: statisticsContent.widthAnchor, constant: -32).isActive = true }
        statisticsContent.setCustomSpacing(6, after: views[1])  // 도움말은 상자 바로 아래
    }

    private func permissionRow(typing: Bool, granted: Bool) -> NSView {
        let title = String(localized: "Input Monitoring Permission")
        if typing, granted {
            let dot = NSView()
            dot.wantsLayer = true
            dot.layer?.backgroundColor = Tokens.signalOn.cgColor
            dot.layer?.cornerRadius = 4
            dot.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([dot.widthAnchor.constraint(equalToConstant: 8), dot.heightAnchor.constraint(equalToConstant: 8)])
            let status = NSTextField(labelWithString: String(localized: "Allowed"))
            status.font = .systemFont(ofSize: 13)
            status.textColor = Tokens.ink
            let pair = NSStackView(views: [dot, status])
            pair.spacing = 6
            return Self.row(title, [pair])
        }
        let status = NSTextField(labelWithString: granted ? String(localized: "Allowed · Not in Use") : String(localized: "Not Allowed"))
        status.font = .systemFont(ofSize: 13)
        status.textColor = Tokens.muted
        let open = NSButton(title: String(localized: "Open System Settings…"), target: self, action: #selector(openPrivacySettings))
        open.controlSize = .small
        return Self.row(title, [status, open])
    }

    @objc private func statisticsChanged() {
        UserDefaults.standard.set(statisticsSwitch.state == .on, forKey: StatsRecorder.enabledKey)
        onStatisticsChanged()
        reloadStatistics()
    }

    @objc private func typingChanged() {
        onTypingChanged(typingSwitch.state == .on)
        reloadStatistics()
    }

    @objc private func openPrivacySettings() {
        SettingsWindow.openInputMonitoringSettings()
    }

    static func openInputMonitoringSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
    }

    // 되돌릴 수 없으니 설정 창 위 시트로 한 번 더 묻는다.
    @objc private func clearStatistics() {
        let alert = NSAlert()
        alert.messageText = String(localized: "Clear all statistics?")
        alert.informativeText = String(localized: "This can’t be undone.")
        let clear = alert.addButton(withTitle: String(localized: "Clear"))
        clear.hasDestructiveAction = true
        alert.addButton(withTitle: String(localized: "Cancel"))
        alert.beginSheetModal(for: window) { [weak self] response in
            if response == .alertFirstButtonReturn { self?.onClearStatistics() }
        }
    }

    // 라벨은 왼쪽, 컨트롤은 오른쪽 끝. 첫 컨트롤은 VoiceOver가 라벨 이름으로 읽는다.
    static func row(_ title: String, _ controls: [NSView]) -> NSView {
        controls.first?.setAccessibilityLabel(title)
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13)  // body
        label.textColor = Tokens.ink
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let row = NSStackView(views: [label, spacer] + controls)
        row.spacing = 8  // space-2
        return row
    }

    // 시스템 설정의 그룹 상자: 배경 group-bg, 모서리 radius-md, 줄마다 최소 row-setting, 줄 사이 line 1pt를 group-inset만큼 들여 긋는다.
    static func group(_ rows: [NSView]) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 0
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)  // group-inset
        stack.translatesAutoresizingMaskIntoConstraints = false
        for (index, row) in rows.enumerated() {
            if index > 0 { stack.addArrangedSubview(fill(Tokens.line, cornerRadius: 0)) }
            stack.addArrangedSubview(row)
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 36).isActive = true  // row-setting
        }
        for view in stack.arrangedSubviews {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -20).isActive = true
            if !rows.contains(view) { view.heightAnchor.constraint(equalToConstant: 1).isActive = true }
        }
        let box = fill(Tokens.groupBackground, cornerRadius: 10)  // radius-md
        let content = box.contentView!
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
        ])
        return box
    }

    // 항목 화면의 세로 줄: 안쪽 여백 space-3, 요소 사이 space-3, 모두 내용 폭을 채운다.
    static func column(_ views: [NSView]) -> NSStackView {
        let column = NSStackView(views: views)
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 16  // space-3
        column.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)  // space-3
        for view in views {
            view.widthAnchor.constraint(equalTo: column.widthAnchor, constant: -32).isActive = true
        }
        return column
    }

    // 색을 채운 판. NSBox는 외관(라이트/다크)이 바뀌면 동적 색으로 다시 그린다.
    private static func fill(_ color: NSColor, cornerRadius: CGFloat) -> NSBox {
        let box = NSBox()
        box.boxType = .custom
        box.borderWidth = 0
        box.cornerRadius = cornerRadius
        box.fillColor = color
        box.contentViewMargins = .zero
        box.translatesAutoresizingMaskIntoConstraints = false
        return box
    }

    static func caption(_ text: String) -> NSTextField {
        let caption = NSTextField(wrappingLabelWithString: text)
        caption.isSelectable = false  // 설명 글자는 시스템 설정처럼 끌어서 선택되지 않게 한다
        caption.font = .systemFont(ofSize: 11)  // caption
        caption.textColor = Tokens.muted
        return caption
    }

    @objc private func showChanged() {
        UserDefaults.standard.set(showSwitch.state == .on, forKey: AppDelegate.showOnSwitchKey)
        onShowChanged()
    }

    @objc private func capsLockChanged() {
        UserDefaults.standard.set(capsLockSwitch.state == .on, forKey: HUD.showCapsLockKey)
        onCapsLockChanged()
    }

    // 등록에 실패하면 실제 상태로 되돌린다.
    @objc private func loginChanged() {
        LoginItem.set(loginSwitch.state == .on)
        loginSwitch.state = LoginItem.isEnabled ? .on : .off
    }

    @objc private func stepperChanged() {
        apply(stepper.doubleValue)
    }

    // 0.5–5.0초, 0.5초 단위. 끝에 닿으면 반대쪽 끝으로 넘어가지 않고 멈춘다(NSStepper 기본값은 넘어간다).
    static func makeDurationStepper() -> NSStepper {
        let stepper = NSStepper()
        stepper.minValue = range.lowerBound
        stepper.maxValue = range.upperBound
        stepper.increment = step
        stepper.valueWraps = false
        return stepper
    }

    // 0.5 단위로 반올림하고 0.5–5.0 범위 안으로 넣는다.
    static func snapped(_ value: Double) -> Double {
        min(max((value / step).rounded() * step, range.lowerBound), range.upperBound)
    }

    // 화면과 UserDefaults에 반영한다.
    private func apply(_ value: Double) {
        let snapped = Self.snapped(value)
        field.stringValue = Self.formatter.string(from: snapped as NSNumber) ?? ""
        stepper.doubleValue = snapped
        UserDefaults.standard.set(snapped, forKey: HUD.durationKey)
    }
}

// MainMenu가 없어 ⌘W가 저절로 동작하지 않으므로 직접 받는다. closesOnEscape면 Esc로도 닫는다.
final class ClosableWindow: NSWindow {
    var closesOnEscape = false

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command, event.charactersIgnoringModifiers == "w" {
            close()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        if closesOnEscape { close() } else { super.cancelOperation(sender) }
    }
}
