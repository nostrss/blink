import AppKit

// 설정 창의 '위치' 항목. 미니 모니터에서 9방위 점을 누르거나 미니 HUD를 끌어 표시 위치를 정한다.
final class PositionPane: NSStackView {
    private let monitor = MiniMonitor()
    private let nameLabel = NSTextField(labelWithString: "")
    private let resetButton = NSButton(title: String(localized: "Reset to Default"), target: nil, action: nil)
    private let oneSourceNote = NSTextField(wrappingLabelWithString: String(localized: "There’s only one input source, so the HUD never appears. You can add more in System Settings > Keyboard > Input Sources."))
    private let preview: (HUDPosition) -> Void
    private let sampleNames: () -> (from: String, to: String?)

    init(preview: @escaping (HUDPosition) -> Void, sampleNames: @escaping () -> (from: String, to: String?)) {
        self.preview = preview
        self.sampleNames = sampleNames
        super.init(frame: .zero)

        monitor.onChange = { [weak self] position, done in self?.moved(to: position, save: done) }
        nameLabel.font = .systemFont(ofSize: 13)  // body
        nameLabel.textColor = Tokens.ink
        resetButton.target = self
        resetButton.action = #selector(reset)
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let foot = NSStackView(views: [nameLabel, spacer, resetButton])
        let caption = NSTextField(wrappingLabelWithString: String(localized: "Click a dot or drag the HUD to move it. While you move it, a preview appears at the same spot on your screen."))
        caption.font = .systemFont(ofSize: 11)  // caption
        caption.textColor = Tokens.muted

        oneSourceNote.font = .systemFont(ofSize: 11)  // caption
        oneSourceNote.textColor = Tokens.muted

        orientation = .vertical
        alignment = .leading
        spacing = 8  // space-2
        edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)  // space-3
        [monitor, foot, caption, oneSourceNote].forEach(addArrangedSubview)
        // 미니 모니터는 16:10을 지키며 내용 폭을 채운다. 창이 낮으면 높이에 맞춰 줄어든다(폭 채우기가 가장 약한 조건).
        let fill = monitor.widthAnchor.constraint(equalTo: widthAnchor, constant: -32)
        fill.priority = NSLayoutConstraint.Priority(490)  // 창 크기 유지(500)보다 약해야 창이 저절로 커지지 않는다
        NSLayoutConstraint.activate([
            fill,
            monitor.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -32),
            monitor.heightAnchor.constraint(equalTo: monitor.widthAnchor, multiplier: 10.0 / 16.0),
            foot.widthAnchor.constraint(equalTo: monitor.widthAnchor),
            caption.widthAnchor.constraint(equalTo: monitor.widthAnchor),
            oneSourceNote.widthAnchor.constraint(equalTo: monitor.widthAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    // 창을 열 때마다 저장된 위치와 지금 이름으로 맞춘다.
    func reload() {
        reloadNames()
        show(HUD.savedPosition)
    }

    // 왼쪽은 현재 입력소스, 오른쪽은 다음에 바뀔 입력소스. 바꿀 곳이 없으면 "없음"과 안내를 보인다.
    func reloadNames() {
        let names = sampleNames()
        monitor.setNames(from: names.from, to: names.to)
        oneSourceNote.isHidden = names.to != nil
    }

    private func moved(to position: HUDPosition, save: Bool) {
        if save { HUD.savedPosition = position }
        show(position)
        preview(position)
    }

    @objc private func reset() {
        moved(to: .center, save: true)
    }

    private func show(_ position: HUDPosition) {
        monitor.position = position
        nameLabel.stringValue = position.presetIndex.map { presetNames[$0] } ?? String(localized: "Custom")
        resetButton.isEnabled = position != .center
    }
}

// 화면을 줄여 그린 사각형. 위쪽 띠는 메뉴바로, HUD가 못 가는 영역이다.
private final class MiniMonitor: NSView {
    private static let menuBar: CGFloat = 8
    private static let margin: CGFloat = 6  // space-4를 미니 모니터 비율로 줄인 여백
    private static let snap: CGFloat = 12

    var onChange: ((HUDPosition, _ done: Bool) -> Void)?
    var position = HUDPosition.center { didSet { needsLayout = true } }

    private let menuBarStrip = Layer(fill: Tokens.surface)
    private let chip = Chip()
    private var dots: [Dot] = []
    private var dragOffset: CGPoint?

    // HUD가 움직일 수 있는 영역: 메뉴바 띠 아래.
    private var area: CGRect { CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height - Self.menuBar) }

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 6  // radius-sm
        layer?.borderWidth = 1
        layer?.masksToBounds = true
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(String(localized: "Display Position"))
        addSubview(menuBarStrip)
        for index in HUDPosition.presets.indices {
            let dot = Dot(index: index)
            dot.setAccessibilityLabel(presetNames[index])
            dot.target = self
            dot.action = #selector(dotClicked)
            dots.append(dot)
            addSubview(dot)
        }
        addSubview(chip)
    }

    required init?(coder: NSCoder) { fatalError() }

    func setNames(from: String, to: String?) {
        chip.set(from: from, to: to)
        needsLayout = true
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.backgroundColor = Tokens.line.cgColor
        layer?.borderColor = Tokens.muted.cgColor
    }

    override func layout() {
        super.layout()
        menuBarStrip.frame = CGRect(x: 0, y: bounds.height - Self.menuBar, width: bounds.width, height: Self.menuBar)
        for (dot, preset) in zip(dots, HUDPosition.presets) {
            let origin = preset.origin(size: chip.size, in: area, margin: Self.margin)
            dot.frame = CGRect(x: origin.x + chip.size.width / 2 - 12, y: origin.y + chip.size.height / 2 - 12, width: 24, height: 24)
        }
        chip.frame = CGRect(origin: position.origin(size: chip.size, in: area, margin: Self.margin), size: chip.size)
        window?.invalidateCursorRects(for: self)
    }

    override func resetCursorRects() {
        addCursorRect(chip.frame, cursor: .openHand)
    }

    // 미니 HUD 위의 클릭은 그 아래 점이 아니라 이 뷰가 받아 끌기로 처리한다.
    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        return chip.frame.contains(local) ? self : super.hitTest(point)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard chip.frame.contains(point) else { return }
        dragOffset = CGPoint(x: point.x - chip.frame.minX, y: point.y - chip.frame.minY)
        NSCursor.closedHand.push()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragOffset else { return }
        let point = convert(event.locationInWindow, from: nil)
        position = HUDPosition.dragged(to: CGPoint(x: point.x - dragOffset.x, y: point.y - dragOffset.y),
                                       size: chip.size, in: area, margin: Self.margin, snap: Self.snap)
        onChange?(position, false)
    }

    override func mouseUp(with event: NSEvent) {
        guard dragOffset != nil else { return }
        dragOffset = nil
        NSCursor.pop()
        onChange?(position, true)
    }

    @objc private func dotClicked(_ sender: Dot) {
        position = HUDPosition.presets[sender.index]
        onChange?(position, true)
    }
}

// HUDPosition.presets와 같은 순서의 프리셋 이름. 아래 줄의 위치 이름과 점의 접근성 라벨에 쓴다.
private let presetNames = [
    String(localized: "Top Left"), String(localized: "Top Center"), String(localized: "Top Right"),
    String(localized: "Middle Left"), String(localized: "Center"), String(localized: "Middle Right"),
    String(localized: "Bottom Left"), String(localized: "Bottom Center"), String(localized: "Bottom Right"),
]

// 프리셋 점. 지름 8pt를 그리고, 누르는 영역은 24pt. 마우스를 올리거나 누르면 accent.
private final class Dot: NSButton {
    let index: Int
    private var hovering = false { didSet { needsDisplay = true } }

    init(index: Int) {
        self.index = index
        super.init(frame: .zero)
        title = ""
        isBordered = false
        setButtonType(.momentaryChange)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        (isHighlighted || hovering ? Tokens.accent : Tokens.muted).setFill()
        NSBezierPath(ovalIn: NSRect(x: bounds.midX - 4, y: bounds.midY - 4, width: 8, height: 8)).fill()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow], owner: self))
    }

    override func mouseEntered(with event: NSEvent) { hovering = true }
    override func mouseExited(with event: NSEvent) { hovering = false }

    override func drawFocusRingMask() {
        NSBezierPath(ovalIn: bounds.insetBy(dx: 4, dy: 4)).fill()
    }

    override var focusRingMaskBounds: NSRect { bounds }
}

// 미니 HUD. HUD와 같은 색으로 '변경 전 → 변경 후'를 작게 그린다.
private final class Chip: NSView {
    // 폭은 이름에 맞추되 72–180pt 안. 넘치면 실제 HUD처럼 '변경 전'부터 말줄임한다.
    private(set) var size = CGSize(width: 96, height: 24)
    private let stack: NSStackView
    private let from = Chip.label(Tokens.muted, weight: .regular)
    private let to = Chip.label(Tokens.hudInk, weight: .semibold)

    init() {
        let arrow = Chip.label(Tokens.accent, weight: .regular)
        stack = NSStackView(views: [from, arrow, to])
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 6  // radius-sm
        shadow = NSShadow()
        layer?.shadowOpacity = 0.18
        layer?.shadowRadius = 4
        layer?.shadowOffset = CGSize(width: 0, height: -2)
        arrow.stringValue = "→"
        from.lineBreakMode = .byTruncatingTail
        from.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        to.lineBreakMode = .byTruncatingTail
        // 이름은 실제 HUD처럼 VoiceOver가 따로 읽지 않는다.
        [self.from, arrow, self.to].forEach { $0.setAccessibilityElement(false) }
        stack.spacing = 4  // space-1
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func set(from: String, to: String?) {
        self.from.stringValue = from
        self.to.stringValue = to ?? String(localized: "None")
        self.to.font = .systemFont(ofSize: 11, weight: to == nil ? .regular : .semibold)
        self.to.textColor = to == nil ? Tokens.muted : Tokens.hudInk
        size.width = min(max(stack.fittingSize.width, 72), 180)
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        let reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        layer?.backgroundColor = (reduce ? Tokens.surface : Tokens.hudBg).cgColor
    }

    private static func label(_ color: NSColor, weight: NSFont.Weight) -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 11, weight: weight)  // caption
        label.textColor = color
        return label
    }
}

// 색 하나로 채운 사각형. updateLayer는 현재 외관으로 불리므로 라이트/다크를 따라간다.
private final class Layer: NSView {
    private let fill: NSColor

    init(fill: NSColor) {
        self.fill = fill
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.backgroundColor = fill.withAlphaComponent(0.8).cgColor
    }
}
