import AppKit

// 설정 창의 '위치' 항목. 미니 모니터에서 9방위 점을 누르거나 미니 HUD를 끌어 표시 위치를 정한다.
final class PositionPane: NSStackView {
    private let monitor = MiniMonitor()
    private let nameLabel = NSTextField(labelWithString: "")
    private let resetButton = NSButton(title: String(localized: "Reset to Default"), target: nil, action: nil)
    private let oneSourceNote = SettingsWindow.caption(String(localized: "There’s only one input source, so the HUD never appears. You can add more in System Settings > Keyboard > Input Sources."))
    private let preview: (HUDPosition) -> Void
    private let sampleNames: () -> (from: InputSourceLabel, to: InputSourceLabel?)

    init(preview: @escaping (HUDPosition) -> Void, sampleNames: @escaping () -> (from: InputSourceLabel, to: InputSourceLabel?)) {
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
        let caption = SettingsWindow.caption(String(localized: "Click a dot or drag the HUD to move it. While you move it, a preview appears at the same spot on your screen."))

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

    // 항목을 열 때마다 저장된 위치·모양과 지금 이름으로 맞춘다.
    func reload() {
        monitor.setLook(HUD.savedAppearance)
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
    private static let menuBar: CGFloat = 12
    private static let margin: CGFloat = 6  // space-4를 미니 모니터 비율로 줄인 여백
    private static let snap: CGFloat = 12

    var onChange: ((HUDPosition, _ done: Bool) -> Void)?
    var position = HUDPosition.center { didSet { needsLayout = true } }

    private let menuBarStrip = MenuBarSkeleton()
    private let chip = HUDChip(style: HUDChip.mini)
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

    func setNames(from: InputSourceLabel, to: InputSourceLabel?) {
        chip.set(from: from, to: to)
        needsLayout = true
    }

    // 미니 HUD를 현재 모양으로 그린다. 크기가 바뀌므로 위치(비율)는 그대로 두고 자리만 다시 잡는다.
    func setLook(_ look: HUDAppearance) {
        chip.look = look
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

// 미니 모니터 위쪽의 메뉴바. 글자·아이콘 없이 스켈레톤으로 그린다.
// 왼쪽은 Apple 메뉴 자리 점과 앱 메뉴 막대 3개, 오른쪽은 상태 아이콘 점 2개와 시계 막대.
// Apple 로고는 상표라 점으로 대신한다. draw는 현재 외관으로 불리므로 라이트/다크를 따라간다.
private final class MenuBarSkeleton: NSView {
    override func draw(_ dirtyRect: NSRect) {
        Tokens.surface.withAlphaComponent(0.8).setFill()
        bounds.fill()
        Tokens.muted.setFill()
        let mid = bounds.midY
        func dot(_ x: CGFloat) { NSBezierPath(ovalIn: NSRect(x: x, y: mid - 2.5, width: 5, height: 5)).fill() }
        func bar(_ x: CGFloat, _ width: CGFloat) {
            NSBezierPath(roundedRect: NSRect(x: x, y: mid - 2, width: width, height: 4), xRadius: 2, yRadius: 2).fill()
        }
        // 왼쪽 끝에서 오른쪽으로
        var x: CGFloat = 6
        dot(x); x += 5 + 5
        for width: CGFloat in [16, 12, 14] { bar(x, width); x += width + 5 }
        // 오른쪽 끝에서 왼쪽으로
        x = bounds.maxX - 6 - 22
        bar(x, 22); x -= 5 + 5
        dot(x); x -= 5 + 5
        dot(x)
    }
}
