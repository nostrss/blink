import AppKit

// 포인터 옆에 현재 입력소스의 약자를 늘 붙여 두는 포인터 배지. 켜져 있는 동안 마우스 이동을 감시해 따라간다.
// 마우스 이벤트 감시는 키 이벤트와 달리 권한이 필요 없어 샌드박스에서도 쓸 수 있다.
final class CursorBadge {
    static let enabledKey = "showPointerBadge"
    static let hidesWhenIdleKey = "pointerBadgeHidesWhenIdle"
    static let placementKey = "pointerBadgePlacement"
    static let sizeKey = "pointerBadgeSize"
    private static let fadeDuration = 0.3

    private let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
    private let badge = CursorBadgeView(blendingMode: .behindWindow)
    private var monitors: [Any] = []
    private var displayOptionsObserver: NSObjectProtocol?
    private var hideTimer: Timer?
    private var placement = BadgePlacement.standard
    private var hidesWhenIdle = false

    init() {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.contentView = badge
        // 약자가 바뀌어 폭이 달라지면(EN → 한) 자리를 다시 잡는다.
        badge.onResize = { [weak self] in self?.move() }
    }

    static var savedPlacement: BadgePlacement {
        get { BadgePlacement(saved: UserDefaults.standard.string(forKey: placementKey)) }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: placementKey) }
    }

    // 배지 크기(작게·보통·크게). HUD '크기'와 따로 저장한다. 없거나 읽을 수 없으면 보통.
    static func size(saved: String?) -> HUDAppearance.Size {
        saved.flatMap(HUDAppearance.Size.init(rawValue:)) ?? .medium
    }

    static var savedSize: HUDAppearance.Size {
        get { size(saved: UserDefaults.standard.string(forKey: sizeKey)) }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: sizeKey) }
    }

    private var isRunning: Bool { !monitors.isEmpty }

    // 설정을 다시 읽는다. 꺼져 있으면 감시를 멈추고 숨긴다. 켜는 순간 포인터 옆에 바로 나타난다.
    func reload(showing label: InputSourceLabel) {
        guard UserDefaults.standard.bool(forKey: Self.enabledKey) else { stop(); return }
        placement = Self.savedPlacement
        hidesWhenIdle = UserDefaults.standard.bool(forKey: Self.hidesWhenIdleKey)
        badge.look = HUD.savedAppearance
        badge.badgeSize = Self.savedSize
        badge.text = label.abbreviation
        if !isRunning { start() }
        reveal()
    }

    // 입력소스가 바뀌면 글자만 바꾸고, 숨어 있었으면 다시 나타난다(타자 중에는 마우스가 멈춰 있으므로).
    func update(_ label: InputSourceLabel) {
        guard isRunning else { return }
        badge.text = label.abbreviation
        reveal()
    }

    // '모양'이 바뀌면 테마 색·크기·굵기를 따라간다.
    func reloadLook() {
        guard isRunning else { return }
        badge.look = HUD.savedAppearance
    }

    private func start() {
        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        // 다른 앱 위의 이동은 전역 감시, Blink 창(설정 창) 위의 이동은 로컬 감시로 받는다.
        if let global = NSEvent.addGlobalMonitorForEvents(matching: events, handler: { [weak self] _ in self?.reveal() }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: events, handler: { [weak self] event in self?.reveal(); return event }) {
            monitors.append(local)
        }
        // '투명도 줄이기'를 바꾸면 배경을 다시 칠한다. 라이트/다크는 뷰가 스스로 따라간다.
        displayOptionsObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main) { [weak self] _ in self?.badge.refresh() }
    }

    private func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        displayOptionsObserver.map(NSWorkspace.shared.notificationCenter.removeObserver)
        displayOptionsObserver = nil
        hideTimer?.invalidate()
        panel.orderOut(nil)
    }

    // 포인터 옆으로 옮기고 보인다. '포인터가 멈추면 숨기기'가 켜져 있으면 표시 시간 뒤에 사라지게 한다.
    private func reveal() {
        move()
        if !panel.isVisible || panel.alphaValue < 1 {
            // 진행 중인 페이드아웃을 끊고 즉시 다시 보인다(페이드인 없음).
            NSAnimationContext.runAnimationGroup { $0.duration = 0; panel.animator().alphaValue = 1 }
            panel.orderFrontRegardless()
        }
        hideTimer?.invalidate()
        guard hidesWhenIdle else { return }
        // '동작 줄이기'가 켜져 있으면 HUD처럼 페이드 없이 같은 시점(표시 시간 + 0.3초)에 사라진다.
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let duration = UserDefaults.standard.double(forKey: HUD.durationKey)
        hideTimer = Timer.scheduledTimer(withTimeInterval: reduceMotion ? duration + Self.fadeDuration : duration, repeats: false) { [weak self] _ in
            guard let self else { return }
            if reduceMotion { self.panel.orderOut(nil) } else { self.fadeOut() }
        }
    }

    // 포인터가 있는 화면 안에서 배지 위치에 놓는다. HUD와 달리 메뉴바·Dock을 빼지 않아, 그 위에서도 포인터를 따라간다.
    private func move() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let frame = screen?.frame else { return }
        let size = badge.size
        let rect = NSRect(origin: placement.origin(size: size, pointer: mouse, in: frame), size: size)
        guard rect != panel.frame else { return }
        let resized = rect.size != panel.frame.size
        panel.setFrame(rect, display: true)
        if resized { panel.invalidateShadow() }  // 그림자를 알약 모양에 맞춘다
    }

    private func fadeOut() {
        NSAnimationContext.runAnimationGroup({ $0.duration = Self.fadeDuration; panel.animator().alphaValue = 0 }) { [weak self] in
            // 페이드 도중 다시 나타났다면 alpha가 1로 돌아와 있다.
            guard let self, self.panel.alphaValue == 0 else { return }
            self.panel.orderOut(nil)
        }
    }
}

// 포인터 배지 한 개를 그리는 뷰. 실제 배지 패널과 설정 '포인터'의 배지 위치 칸이 같이 쓴다.
// 크기는 HUD '크기'와 따로 정하는 배지 크기를 따르고, 모서리는 늘 알약이다. 색·굵기는 모양을, 라이트/다크는 이 뷰의 외관을 따른다.
final class CursorBadgeView: NSView {
    private let effect = NSVisualEffectView()
    private let tint = NSView()
    private let label = NSTextField(labelWithString: "")

    var look = HUDAppearance() { didSet { refresh() } }
    var badgeSize = HUDAppearance.Size.medium { didSet { if badgeSize != oldValue { refresh() } } }
    var text = "" { didSet { if text != oldValue { refresh() } } }
    // 설정 칸에서 크게 그릴 때의 배율.
    var magnification: CGFloat = 1 { didSet { if magnification != oldValue { refresh() } } }
    var onResize: (() -> Void)?
    private(set) var size = CGSize(width: 24, height: 24)

    init(blendingMode: NSVisualEffectView.BlendingMode) {
        super.init(frame: NSRect(origin: .zero, size: size))
        effect.material = .hudWindow
        effect.blendingMode = blendingMode
        effect.state = .active
        tint.wantsLayer = true
        for view in [effect, tint] {
            view.frame = bounds
            view.autoresizingMask = [.width, .height]
            addSubview(view)
        }
        addSubview(label)
        setAccessibilityElement(false)  // 입력소스는 VoiceOver가 이미 읽어 준다.
        label.setAccessibilityElement(false)
        refresh()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refresh()
    }

    // 글자 16pt(cursor-badge)에 HUD와 같은 배율(0.8 · 1 · 1.3)을 곱한다. 높이는 글자 × 2.2, 좌우 패딩은 글자 × 0.5
    // (한글 한 글자 폭이 글자 크기쯤이라, 이보다 크면 한 글자 배지가 원이 아니라 가로로 길어진다).
    static func metrics(_ size: HUDAppearance.Size) -> (font: CGFloat, height: CGFloat, padding: CGFloat) {
        let font = (16 * size.scale).rounded()
        return (font, (font * 2.2).rounded(), (font * 0.5).rounded())
    }

    // 글자 + 좌우 패딩, 높이보다 좁아지지 않게 한다(한 글자면 원, 두 글자면 가로로 긴 알약).
    static func width(text: CGFloat, height: CGFloat, padding: CGFloat) -> CGFloat {
        max((text + padding * 2).rounded(.up), height)
    }

    // 모양·글자·외관이 바뀔 때마다 색과 크기를 다시 정한다. 자리는 쓰는 쪽이 size로 잡는다.
    func refresh() {
        let reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        let colors = look.colors(effectiveAppearance.hudMode, reduceTransparency: reduce)
        let metrics = Self.metrics(badgeSize)
        let height = metrics.height * magnification
        label.font = .systemFont(ofSize: metrics.font * magnification, weight: look.bold ? .bold : .semibold)  // 변경 후 굵기
        label.stringValue = text
        label.textColor = NSColor(colors.to)
        tint.layer?.backgroundColor = NSColor(colors.background).cgColor
        tint.layer?.cornerRadius = height / 2
        effect.alphaValue = colors.blur
        // 흐림은 layer cornerRadius로 잘리지 않아 모서리에 네모가 비친다. HUD처럼 maskImage로 자른다.
        effect.maskImage = HUD.roundedMask(radius: height / 2)
        let newSize = CGSize(width: Self.width(text: label.fittingSize.width, height: height, padding: metrics.padding * magnification), height: height)
        needsLayout = true
        if newSize != size {
            size = newSize
            onResize?()
        }
    }

    override func layout() {
        super.layout()
        let fit = label.fittingSize
        label.frame = NSRect(x: ((bounds.width - fit.width) / 2).rounded(), y: ((bounds.height - fit.height) / 2).rounded(), width: fit.width, height: fit.height)
    }
}
