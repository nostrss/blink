import AppKit

// 메뉴 "설정…"으로 여는 창. 왼쪽 사이드바에서 항목을 고르면 오른쪽에 그 항목의 설정이 나온다.
// 저장 버튼 없이 바로 적용한다. 새 설정은 사이드바에 항목을 추가해서 넣는다.
final class SettingsWindow: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSToolbarDelegate {
    private static let range = 0.5...5.0
    private static let step = 0.5

    private enum Pane: Int, CaseIterable {
        case general, position, appearance

        var title: String {
            switch self {
            case .general: String(localized: "General")
            case .position: String(localized: "Position")
            case .appearance: String(localized: "Appearance")
            }
        }
    }

    private let window = ClosableWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 440),
                                        styleMask: [.titled, .closable, .resizable, .fullSizeContentView], backing: .buffered, defer: true)
    private let split = NSSplitViewController()
    private let sidebar = NSTableView()
    private let detail = NSView()
    private lazy var panes: [Pane: NSView] = [.general: makeGeneralPane(), .position: positionPane, .appearance: appearancePane]
    private let positionPane: PositionPane
    private let appearancePane: AppearancePane

    private let showSwitch = NSSwitch()
    private let loginSwitch = NSSwitch()
    private let field = NSTextField()
    private let stepper = SettingsWindow.makeDurationStepper()
    private let onShowChanged: () -> Void
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 1
        return f
    }()

    // onShowChanged: '언어 전환 HUD 표시'를 바꾼 직후(메뉴바 아이콘 갱신용)
    // preview: 위치·모양을 고르는 동안 실제 화면에 HUD를 띄운다. sampleNames: 미니 HUD와 미리보기에 쓸 이름
    init(onShowChanged: @escaping () -> Void, preview: @escaping (HUDPosition) -> Void,
         sampleNames: @escaping () -> (from: InputSourceLabel, to: InputSourceLabel?)) {
        self.onShowChanged = onShowChanged
        positionPane = PositionPane(preview: preview, sampleNames: sampleNames)
        appearancePane = AppearancePane(preview: { preview(HUD.savedPosition) }, sampleNames: sampleNames)
        super.init()
        window.isReleasedWhenClosed = false
        window.backgroundColor = Tokens.surface

        sidebar.style = .sourceList
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
        }
    }

    func show() {
        select(.general)
        sidebar.selectRowIndexes([Pane.general.rawValue], byExtendingSelection: false)
        showSwitch.state = UserDefaults.standard.bool(forKey: AppDelegate.showOnSwitchKey) ? .on : .off
        loginSwitch.state = LoginItem.isEnabled ? .on : .off
        apply(UserDefaults.standard.double(forKey: HUD.durationKey))
        NSApp.activateForWindow()
        window.makeKeyAndOrderFront(nil)
    }

    // 창이 열려 있는 동안 입력소스가 바뀌면 미니 HUD 이름을 맞춘다.
    func reloadNames() {
        positionPane.reloadNames()
        appearancePane.reloadNames()
    }

    private func select(_ pane: Pane) {
        window.title = pane.title
        detail.subviews.forEach { $0.removeFromSuperview() }
        // 항목을 열 때마다 저장된 값으로 맞춘다('모양'에서 바꾼 모양이 '위치'의 미니 HUD에 보이도록).
        if pane == .position { positionPane.reload() }
        if pane == .appearance { appearancePane.reload() }
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

    func numberOfRows(in tableView: NSTableView) -> Int { Pane.allCases.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = NSTableCellView()
        let label = NSTextField(labelWithString: Pane(rawValue: row)!.title)
        label.font = .systemFont(ofSize: 13)  // body
        label.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(label)
        cell.textField = label
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),  // space-1
            label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        if let pane = Pane(rawValue: sidebar.selectedRow) { select(pane) }
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
        for toggle in [showSwitch, loginSwitch] {
            toggle.controlSize = .small
            toggle.target = self
        }
        showSwitch.action = #selector(showChanged)
        loginSwitch.action = #selector(loginChanged)
        let showRow = Self.row(String(localized: "Show HUD on Input Switch"), [showSwitch])
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

        let separator = NSBox()
        separator.boxType = .separator

        let rows = [showRow, loginRow, separator, durationRow]
        let column = NSStackView(views: rows)
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 8  // space-2
        column.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)  // space-3
        for row in rows {
            row.widthAnchor.constraint(equalTo: column.widthAnchor, constant: -32).isActive = true
        }
        return column
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
