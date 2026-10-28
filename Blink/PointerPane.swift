import AppKit

// 설정 창의 '포인터' 항목. 포인터 배지를 켜고, 배지 위치(포인터 둘레 8방위)와 멈추면 숨기기를 정한다.
// 켜면 설정 창 위의 실제 포인터에 배지가 바로 붙으므로 따로 미리보기를 띄우지 않는다.
final class PointerPane: NSStackView {
    private let showSwitch = NSSwitch()
    private let hideSwitch = NSSwitch()
    private let picker = BadgePicker()
    private let sizeControl = NSSegmentedControl(labels: [String(localized: "Small"), String(localized: "Medium"), String(localized: "Large")],
                                                 trackingMode: .selectOne, target: nil, action: nil)
    private let nameLabel = NSTextField(labelWithString: "")
    private let resetButton = NSButton(title: String(localized: "Reset to Default"), target: nil, action: nil)
    private let details = NSStackView()
    private let onChange: () -> Void
    private let sampleNames: () -> (from: InputSourceLabel, to: InputSourceLabel?)

    // onChange: 설정을 바꾼 직후(실제 배지를 다시 읽게 한다). sampleNames: 칸의 배지에 쓸 현재 입력소스.
    init(onChange: @escaping () -> Void, sampleNames: @escaping () -> (from: InputSourceLabel, to: InputSourceLabel?)) {
        self.onChange = onChange
        self.sampleNames = sampleNames
        super.init(frame: .zero)

        for toggle in [showSwitch, hideSwitch] {
            toggle.controlSize = .small
            toggle.target = self
        }
        showSwitch.action = #selector(showChanged)
        hideSwitch.action = #selector(hideChanged)
        picker.onPick = { [weak self] placement in self?.picked(placement) }
        sizeControl.controlSize = .small
        sizeControl.target = self
        sizeControl.action = #selector(sizeChanged)
        nameLabel.font = .systemFont(ofSize: 13)  // body
        nameLabel.textColor = Tokens.ink
        resetButton.target = self
        resetButton.action = #selector(reset)
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let foot = NSStackView(views: [nameLabel, spacer, resetButton])
        let hideRow = SettingsWindow.row(String(localized: "Hide When Pointer Stops"), [hideSwitch])
        // HUD '모양'의 '크기'와 같은 컨트롤이지만 값은 따로 저장한다.
        let sizeRow = SettingsWindow.row(String(localized: "Badge Size"), [sizeControl])

        // 꺼져 있으면 아래 줄들을 흐리게 두지 않고 뺀다(쓸 수 없는 컨트롤은 뺀다).
        details.orientation = .vertical
        details.alignment = .leading
        details.spacing = 16  // space-3
        let detailRows = [picker, foot, SettingsWindow.group([sizeRow]), SettingsWindow.group([hideRow])]
        detailRows.forEach(details.addArrangedSubview)
        details.setCustomSpacing(8, after: picker)  // space-2: 칸 아래 위치 이름 줄

        orientation = .vertical
        alignment = .leading
        spacing = 16  // space-3
        edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)  // space-3
        let showRow = SettingsWindow.group([SettingsWindow.row(String(localized: "Show Input Source Next to Pointer"), [showSwitch])])
        [showRow, details].forEach(addArrangedSubview)
        NSLayoutConstraint.activate([
            showRow.widthAnchor.constraint(equalTo: widthAnchor, constant: -32),
            details.widthAnchor.constraint(equalTo: widthAnchor, constant: -32),
            picker.heightAnchor.constraint(equalToConstant: 160),
        ] + detailRows.map { $0.widthAnchor.constraint(equalTo: details.widthAnchor) })
    }

    required init?(coder: NSCoder) { fatalError() }

    // 항목을 열 때마다 저장된 값과 지금 모양·이름으로 맞춘다.
    func reload() {
        let defaults = UserDefaults.standard
        showSwitch.state = defaults.bool(forKey: CursorBadge.enabledKey) ? .on : .off
        hideSwitch.state = defaults.bool(forKey: CursorBadge.hidesWhenIdleKey) ? .on : .off
        details.isHidden = showSwitch.state == .off
        picker.look = HUD.savedAppearance
        picker.badgeSize = CursorBadge.savedSize
        sizeControl.selectedSegment = HUDAppearance.Size.allCases.firstIndex(of: CursorBadge.savedSize)!
        reloadNames()
        show(CursorBadge.savedPlacement)
    }

    func reloadNames() {
        picker.text = sampleNames().from.abbreviation
    }

    private func show(_ placement: BadgePlacement) {
        picker.placement = placement
        nameLabel.stringValue = placement.title
        resetButton.isEnabled = placement != .standard
    }

    private func picked(_ placement: BadgePlacement) {
        CursorBadge.savedPlacement = placement
        show(placement)
        onChange()
    }

    @objc private func showChanged() {
        UserDefaults.standard.set(showSwitch.state == .on, forKey: CursorBadge.enabledKey)
        details.isHidden = showSwitch.state == .off
        onChange()
    }

    @objc private func sizeChanged() {
        CursorBadge.savedSize = HUDAppearance.Size.allCases[sizeControl.selectedSegment]
        picker.badgeSize = CursorBadge.savedSize
        onChange()
    }

    @objc private func hideChanged() {
        UserDefaults.standard.set(hideSwitch.state == .on, forKey: CursorBadge.hidesWhenIdleKey)
        onChange()
    }

    @objc private func reset() {
        picked(.standard)
    }
}

extension BadgePlacement {
    // '위치'의 프리셋 이름과 같은 말을 쓴다.
    var title: String {
        switch self {
        case .topLeft: String(localized: "Top Left")
        case .top: String(localized: "Top Center")
        case .topRight: String(localized: "Top Right")
        case .left: String(localized: "Middle Left")
        case .right: String(localized: "Middle Right")
        case .bottomLeft: String(localized: "Bottom Left")
        case .bottom: String(localized: "Bottom Center")
        case .bottomRight: String(localized: "Bottom Right")
        }
    }
}

// 배지 위치 칸. 가운데에 화살표 포인터를 그리고 둘레 8곳에 점을 둔다. 고른 자리에는 점 대신 배지를 그린다.
// 점 사이를 넓히려고 실제보다 키워 그리되(최대 2배), 위아래 배지 두 개와 포인터 영역이 칸에 들어가도록 배율을 맞춘다.
private final class BadgePicker: NSView {
    var onPick: ((BadgePlacement) -> Void)?
    var placement = BadgePlacement.standard { didSet { needsLayout = true } }
    var look: HUDAppearance {
        get { badge.look }
        set { badge.look = newValue; needsLayout = true }
    }
    var badgeSize: HUDAppearance.Size {
        get { badge.badgeSize }
        set { badge.badgeSize = newValue; needsLayout = true }
    }
    var text: String {
        get { badge.text }
        set { badge.text = newValue; needsLayout = true }
    }

    private let badge = CursorBadgeView(blendingMode: .withinWindow)
    private var dots: [Dot] = []
    private var pointer = CGPoint.zero
    private var scale: CGFloat = 2

    init() {
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(String(localized: "Badge Position"))
        for (index, placement) in BadgePlacement.allCases.enumerated() {
            let dot = Dot(index: index)
            dot.setAccessibilityLabel(placement.title)
            dot.target = self
            dot.action = #selector(dotClicked)
            dots.append(dot)
            addSubview(dot)
        }
        badge.wantsLayer = true
        badge.shadow = NSShadow()
        badge.layer?.shadowOpacity = 0.18
        badge.layer?.shadowRadius = 4
        badge.layer?.shadowOffset = CGSize(width: 0, height: -2)
        addSubview(badge)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        // 위아래로 배지 두 개와 포인터 영역이 들어갈 만큼만 키운다(위아래 여백 space-2).
        let height = CursorBadgeView.metrics(badgeSize).height
        scale = min(2, (bounds.height - 16) / (height * 2 + BadgePlacement.pointerArea.height + BadgePlacement.gap * 2))
        badge.magnification = scale
        // 포인터 영역이 칸 가운데에 오도록 끝점을 잡고, 1배 좌표에서 자리를 구한 뒤 배율을 곱한다.
        let area = BadgePlacement.pointerArea
        pointer = CGPoint(x: bounds.midX - area.midX * scale, y: bounds.midY + area.midY * scale)
        let unit = CGSize(width: badge.size.width / scale, height: badge.size.height / scale)
        let space = CGRect(x: 0, y: 0, width: bounds.width / scale, height: bounds.height / scale)
        for (dot, candidate) in zip(dots, BadgePlacement.allCases) {
            let origin = candidate.origin(size: unit, pointer: CGPoint(x: pointer.x / scale, y: pointer.y / scale), in: space)
            let rect = CGRect(x: origin.x * scale, y: origin.y * scale, width: badge.size.width, height: badge.size.height)
            dot.frame = CGRect(x: rect.midX - 12, y: rect.midY - 12, width: 24, height: 24)
            dot.isHidden = candidate == placement
            if candidate == placement { badge.frame = rect }
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        Tokens.line.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 10, yRadius: 10).fill()  // radius-md
        // 시스템 화살표 포인터 모양. 끝점이 pointer이고 아래로 그린다.
        let points: [(CGFloat, CGFloat)] = [(0, 0), (0, 15), (3.6, 11.6), (6.2, 17.6), (8.6, 16.6), (6, 10.8), (11, 10.8)]
        let arrow = NSBezierPath()
        for (index, (x, y)) in points.enumerated() {
            let point = CGPoint(x: pointer.x + x * scale, y: pointer.y - y * scale)
            if index == 0 { arrow.move(to: point) } else { arrow.line(to: point) }
        }
        arrow.close()
        arrow.lineJoinStyle = .round
        arrow.lineWidth = 1.2 * scale
        NSColor.white.setStroke()
        arrow.stroke()
        NSColor.black.setFill()
        arrow.fill()
    }

    @objc private func dotClicked(_ sender: Dot) {
        placement = BadgePlacement.allCases[sender.index]
        onPick?(placement)
    }
}
