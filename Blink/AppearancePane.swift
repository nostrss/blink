import AppKit

// 설정 창의 '모양' 항목. HUD의 테마·크기·모서리·글자 굵기·표시 방식·변경 전 표시를 정한다.
// 내용이 최소 크기 창보다 길어서 이 화면 안에서 스크롤한다.
final class AppearancePane: NSScrollView {
    private var look = HUD.savedAppearance
    // 사용자 지정에서 편집 중인 모드. 미리보기 칸을 눌러 바꾼다.
    private var editing = NSApp.effectiveAppearance.hudMode

    private let cells = [PreviewCell(mode: .light), PreviewCell(mode: .dark)]
    private let themePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let customRows = NSStackView()
    private let textWell = NSColorWell()
    private let fromWell = NSColorWell()
    private let arrowWell = NSColorWell()
    private let backgroundWell = NSColorWell()
    private let opacitySlider = NSSlider(value: 1, minValue: 0, maxValue: 1, target: nil, action: nil)
    private let opacityLabel = NSTextField(labelWithString: "")
    private let lowContrastNote = SettingsWindow.caption(String(localized: "Text may be hard to read."))
    // 투명도 줄이기가 켜져 있으면 슬라이더와 숫자 대신 보인다. 누르면 시스템 설정의 그 화면을 연다.
    private let reduceTransparencyLink = LinkLabel(String(localized: "Turn Off Reduce Transparency"))
    private let reduceTransparencyNote = SettingsWindow.caption(String(localized: "Reduce Transparency is on in Accessibility, so the background is always shown opaque."))
    private let sizeControl = AppearancePane.segments([String(localized: "Small"), String(localized: "Medium"), String(localized: "Large")])
    private let cornersControl = AppearancePane.segments([String(localized: "Square"), String(localized: "Default"), String(localized: "Pill")])
    private let weightControl = AppearancePane.segments([String(localized: "Regular"), String(localized: "Bold")])
    private let displayControl = AppearancePane.segments([String(localized: "Name"), String(localized: "Abbreviation")])
    private let fromSwitch = NSSwitch()
    private let resetButton = NSButton(title: String(localized: "Reset to Default"), target: nil, action: nil)
    private let column = NSStackView()
    private let preview: () -> Void
    private let sampleNames: () -> (from: InputSourceLabel, to: InputSourceLabel?)

    // preview: 바꾸는 동안 실제 화면에 HUD를 띄운다. sampleNames: 미리보기에 쓸 이름
    init(preview: @escaping () -> Void, sampleNames: @escaping () -> (from: InputSourceLabel, to: InputSourceLabel?)) {
        self.preview = preview
        self.sampleNames = sampleNames
        super.init(frame: .zero)
        drawsBackground = false
        hasVerticalScroller = true
        autohidesScrollers = true

        let previews = NSStackView(views: zip(cells, [String(localized: "Light"), String(localized: "Dark")]).map { cell, title in
            cell.setAccessibilityLabel(title)
            cell.onClick = { [weak self] in self?.edit(cell.mode) }
            let column = NSStackView(views: [SettingsWindow.caption(title), cell])
            column.orientation = .vertical
            column.alignment = .leading
            column.spacing = 4  // space-1
            cell.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
            return column
        })
        previews.distribution = .fillEqually
        previews.spacing = 8  // space-2

        for theme in HUDTheme.allCases {
            if theme == .custom { themePopup.menu?.addItem(.separator()) }
            themePopup.addItem(withTitle: theme.title)
            themePopup.lastItem?.image = Self.swatch(theme)
            themePopup.lastItem?.representedObject = theme.rawValue
        }
        themePopup.target = self
        themePopup.action = #selector(themeChanged)
        themePopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true

        for well in [textWell, fromWell, arrowWell, backgroundWell] {
            well.target = self
            well.action = #selector(customChanged)
            well.isContinuous = true  // 컬러 패널에서 끄는 동안에도 미리보기와 실제 HUD를 갱신한다
            well.widthAnchor.constraint(equalToConstant: 44).isActive = true
        }
        opacitySlider.target = self
        opacitySlider.action = #selector(customChanged)
        opacitySlider.isContinuous = true
        opacitySlider.widthAnchor.constraint(equalToConstant: 120).isActive = true
        opacityLabel.font = .systemFont(ofSize: 13)  // body
        opacityLabel.textColor = Tokens.ink
        opacityLabel.alignment = .right
        opacityLabel.widthAnchor.constraint(equalToConstant: 40).isActive = true
        reduceTransparencyLink.onClick = { Self.openReduceTransparencySettings() }
        let customViews = [
            SettingsWindow.caption(String(localized: "Click the Light or Dark preview to choose which colors to edit.")),
            // HUD 왼쪽부터: 변경 전 → 화살표 → 변경 후.
            SettingsWindow.row(String(localized: "Previous Source Color"), [fromWell]),
            SettingsWindow.row(String(localized: "Arrow Color"), [arrowWell]),
            SettingsWindow.row(String(localized: "New Source Color"), [textWell]),
            SettingsWindow.row(String(localized: "Background Color"), [backgroundWell]),
            SettingsWindow.row(String(localized: "Background Opacity"), [opacitySlider, opacityLabel, reduceTransparencyLink]),
            reduceTransparencyNote,
            lowContrastNote,
        ]
        customViews.forEach(customRows.addArrangedSubview)
        customRows.orientation = .vertical
        customRows.alignment = .leading
        customRows.spacing = 8  // space-2
        for view in customViews {
            view.widthAnchor.constraint(equalTo: customRows.widthAnchor).isActive = true
        }

        for control in [sizeControl, cornersControl, weightControl, displayControl] {
            control.target = self
            control.action = #selector(optionChanged)
        }
        fromSwitch.controlSize = .small
        fromSwitch.target = self
        fromSwitch.action = #selector(optionChanged)
        resetButton.target = self
        resetButton.action = #selector(reset)
        let resetRow = NSStackView(views: [NSView(), resetButton])

        let fromRow = SettingsWindow.row(String(localized: "Show Previous Input Source"), [fromSwitch])
        let rows: [NSView] = [
            previews,
            SettingsWindow.row(String(localized: "Theme"), [themePopup]),
            customRows,
            Self.separator(),
            SettingsWindow.row(String(localized: "Size"), [sizeControl]),
            SettingsWindow.row(String(localized: "Corners"), [cornersControl]),
            SettingsWindow.row(String(localized: "Font Weight"), [weightControl]),
            Self.separator(),
            SettingsWindow.row(String(localized: "Display Style"), [displayControl]),
            fromRow,
            resetRow,
        ]
        rows.forEach(column.addArrangedSubview)
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 8  // space-2
        column.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)  // space-3
        column.translatesAutoresizingMaskIntoConstraints = false
        for row in rows {
            row.widthAnchor.constraint(equalTo: column.widthAnchor, constant: -32).isActive = true
        }

        let document = FlippedView()
        document.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(column)
        documentView = document
        NSLayoutConstraint.activate([
            document.topAnchor.constraint(equalTo: contentView.topAnchor),
            document.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            document.widthAnchor.constraint(equalTo: contentView.widthAnchor),
            column.topAnchor.constraint(equalTo: document.topAnchor),
            column.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            column.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            column.bottomAnchor.constraint(equalTo: document.bottomAnchor),
        ])

        // '투명도 줄이기'를 바꾸면 미리보기와 안내를 바로 맞춘다.
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refresh()
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    // 사용자 지정 색 줄까지 펼쳤을 때 내용 높이. 설정 창을 처음 열 때 기본 높이로 쓴다(언어마다 문구 길이가 달라 계산한다).
    func fullHeight(width: CGFloat) -> CGFloat {
        let saved = (customRows.isHidden, lowContrastNote.isHidden, reduceTransparencyNote.isHidden)
        customRows.isHidden = false
        lowContrastNote.isHidden = true
        reduceTransparencyNote.isHidden = !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        let fixed = column.widthAnchor.constraint(equalToConstant: width)
        fixed.isActive = true
        // 여러 줄 도움말은 폭을 알려 줘야 줄바꿈한 높이로 잰다.
        let captions = Self.wrappingLabels(in: column).filter { !($0 is LinkLabel) }
        captions.forEach { $0.preferredMaxLayoutWidth = width - 32 }
        defer {
            fixed.isActive = false
            captions.forEach { $0.preferredMaxLayoutWidth = 0 }
            (customRows.isHidden, lowContrastNote.isHidden, reduceTransparencyNote.isHidden) = saved
        }
        return column.fittingSize.height
    }

    // 항목을 열 때마다 저장된 모양과 지금 이름으로 맞춘다.
    func reload() {
        look = HUD.savedAppearance
        editing = NSApp.effectiveAppearance.hudMode
        reloadNames()
        refresh()
    }

    func reloadNames() {
        let names = sampleNames()
        cells.forEach { $0.chip.set(from: names.from, to: names.to) }
    }

    // MARK: 바꾸기

    @objc private func themeChanged() {
        guard let raw = themePopup.selectedItem?.representedObject as? String, let theme = HUDTheme(rawValue: raw) else { return }
        look.select(theme)
        save()
    }

    @objc private func customChanged() {
        guard var colors = look.custom(editing) else { return }
        if let text = textWell.color.rgba { colors.text = text.withAlpha(1) }
        if let from = fromWell.color.rgba { colors.from = from.withAlpha(1) }
        if let arrow = arrowWell.color.rgba { colors.arrow = arrow.withAlpha(1) }
        if let background = backgroundWell.color.rgba { colors.background = background.withAlpha(opacitySlider.doubleValue) }
        look.setCustom(colors, for: editing)
        save()
    }

    @objc private func optionChanged() {
        look.size = HUDAppearance.Size.allCases[sizeControl.selectedSegment]
        look.corners = HUDAppearance.Corners.allCases[cornersControl.selectedSegment]
        look.bold = weightControl.selectedSegment == 1
        look.showsFrom = fromSwitch.state == .on
        look.display = HUDAppearance.Display.allCases[displayControl.selectedSegment]
        save()
    }

    // 사용자 지정 색까지 지운다.
    @objc private func reset() {
        look = .standard
        save()
    }

    private func edit(_ mode: HUDMode) {
        guard look.theme == .custom else { return }
        editing = mode
        refresh()
    }

    // 저장하고 화면을 맞춘 뒤, 실제 화면에 HUD를 띄운다.
    private func save() {
        HUD.savedAppearance = look
        refresh()
        preview()
    }

    private func refresh() {
        cells.forEach {
            $0.chip.look = look
            $0.isSelected = look.theme == .custom && $0.mode == editing
            $0.needsLayout = true
        }
        themePopup.selectItem(at: themePopup.indexOfItem(withRepresentedObject: look.theme.rawValue))
        customRows.isHidden = look.theme != .custom
        if let colors = look.custom(editing) {
            textWell.color = NSColor(colors.text)
            fromWell.color = NSColor(colors.from)
            arrowWell.color = NSColor(colors.arrow)
            backgroundWell.color = NSColor(colors.background.withAlpha(1))
            opacitySlider.doubleValue = colors.background.alpha
            opacityLabel.stringValue = colors.background.alpha.formatted(.percent.precision(.fractionLength(0)))
            lowContrastNote.isHidden = !colors.isLowContrast
        }
        // 켜져 있으면 HUD 배경을 늘 불투명하게 그리므로, 슬라이더와 숫자 대신 끄러 가는 링크와 이유를 보인다.
        // 저장된 불투명도는 그대로 두었다가 끄면 다시 보인다.
        let reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        reduceTransparencyNote.isHidden = !reduce
        reduceTransparencyLink.isHidden = !reduce
        opacitySlider.isHidden = reduce
        opacityLabel.isHidden = reduce
        sizeControl.selectedSegment = HUDAppearance.Size.allCases.firstIndex(of: look.size)!
        cornersControl.selectedSegment = HUDAppearance.Corners.allCases.firstIndex(of: look.corners)!
        weightControl.selectedSegment = look.bold ? 1 : 0
        fromSwitch.state = look.showsFrom ? .on : .off
        displayControl.selectedSegment = HUDAppearance.Display.allCases.firstIndex(of: look.display)!
        resetButton.isEnabled = look != .standard
    }

    // MARK: 부품

    private static func segments(_ labels: [String]) -> NSSegmentedControl {
        let control = NSSegmentedControl(labels: labels, trackingMode: .selectOne, target: nil, action: nil)
        control.controlSize = .small
        return control
    }

    private static func wrappingLabels(in view: NSView) -> [NSTextField] {
        view.subviews.flatMap { sub -> [NSTextField] in
            if let label = sub as? NSTextField, label.cell?.wraps == true { return [label] }
            return wrappingLabels(in: sub)
        }
    }

    // 시스템 설정의 손쉬운 사용 > 디스플레이. 주소는 공식 문서가 없어 버전마다 다를 수 있으므로,
    // 먼저 macOS 13 이후 주소로 디스플레이 화면을, 안 되면 손쉬운 사용 첫 화면을 연다.
    private static func openReduceTransparencySettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.Accessibility-Settings.extension?Display",
            "x-apple.systempreferences:com.apple.preference.universalaccess?Seeing_Display",
            "x-apple.systempreferences:com.apple.preference.universalaccess",
        ].compactMap(URL.init(string:))
        _ = urls.first { NSWorkspace.shared.open($0) }
    }

    private static func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }

    // 테마 메뉴의 견본(22×14pt): 테마 배경색 위에 화살표 색 "→". 그릴 때의 외관(라이트/다크) 색을 쓴다.
    private static func swatch(_ theme: HUDTheme) -> NSImage {
        NSImage(size: NSSize(width: 22, height: 14), flipped: false) { rect in
            let mode = NSAppearance.currentDrawing().hudMode
            let colors = theme.presetColors(mode)
            let path = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 4, yRadius: 4)
            (colors.map { NSColor($0.background.withAlpha(1)) } ?? Tokens.line).setFill()
            path.fill()
            NSColor.black.withAlphaComponent(0.12).setStroke()
            path.stroke()
            let mark = colors == nil ? "…" : "→"
            let text = NSAttributedString(string: mark, attributes: [
                .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
                .foregroundColor: colors.map { NSColor($0.arrow) } ?? Tokens.muted,
            ])
            let size = text.size()
            text.draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2))
            return true
        }
    }
}

extension HUDTheme {
    // Dracula·Gruvbox·Rosé Pine은 고유 이름이라 번역하지 않는다.
    var title: String {
        switch self {
        case .standard: String(localized: "Default")
        case .highContrast: String(localized: "High Contrast")
        case .dracula: "Dracula"
        case .gruvbox: "Gruvbox"
        case .rosePine: "Rosé Pine"
        case .custom: String(localized: "Custom Theme")
        }
    }
}

// 미리보기 칸 하나. 외관을 라이트나 다크로 고정해 그 모드의 HUD를 보여 준다.
// 사용자 지정일 때는 눌러서 편집할 모드를 고르고, 고른 칸은 accent 2pt 테두리.
private final class PreviewCell: NSView {
    let mode: HUDMode
    let chip = HUDChip(style: HUDChip.preview)
    var onClick: (() -> Void)?
    var isSelected = false { didSet { needsDisplay = true } }

    init(mode: HUDMode) {
        self.mode = mode
        super.init(frame: .zero)
        appearance = NSAppearance(named: mode == .light ? .aqua : .darkAqua)
        wantsLayer = true
        layer?.cornerRadius = 10  // radius-md
        addSubview(chip)
        heightAnchor.constraint(equalToConstant: 96).isActive = true
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.backgroundColor = Tokens.line.cgColor
        layer?.borderWidth = isSelected ? 2 : 0
        layer?.borderColor = Tokens.accent.cgColor
    }

    override func layout() {
        super.layout()
        chip.widthLimit = bounds.width - 16
        chip.frame = CGRect(x: ((bounds.width - chip.size.width) / 2).rounded(), y: ((bounds.height - chip.size.height) / 2).rounded(),
                            width: chip.size.width, height: chip.size.height)
    }

    override func mouseDown(with event: NSEvent) { onClick?() }

    override func accessibilityPerformPress() -> Bool {
        onClick?()
        return true
    }
}

private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

// 누르면 onClick을 부르는 링크 모양 글자(강조색, ↗). 오른쪽 정렬이고, 길면 220pt에서 줄바꿈해 두 줄까지 쓴다.
private final class LinkLabel: NSTextField {
    var onClick: (() -> Void)?

    init(_ text: String) {
        super.init(frame: .zero)
        stringValue = text + " ↗"
        isEditable = false
        isSelectable = false
        isBordered = false
        drawsBackground = false
        font = .systemFont(ofSize: 13)  // body
        textColor = .linkColor
        alignment = .right
        cell?.wraps = true
        maximumNumberOfLines = 2
        preferredMaxLayoutWidth = 220
        setAccessibilityRole(.link)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func mouseDown(with event: NSEvent) { onClick?() }

    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }

    override func accessibilityPerformPress() -> Bool {
        onClick?()
        return true
    }
}
