import AppKit

// "변경 전 → 변경 후"를 마우스가 있는 화면의 표시 위치에 잠깐 띄우는 오버레이. 패널 하나를 재사용한다.
final class HUD {
    static let durationKey = "hudDuration"
    static let positionXKey = "hudPositionX"
    static let positionYKey = "hudPositionY"
    static let appearanceKey = "hudAppearance"
    private static let screenMargin: CGFloat = 24  // space-4
    private static let fadeDuration = 0.3

    private let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
    private let effect = NSVisualEffectView()
    private let tint = NSView()
    private let fromLabel = HUD.label()
    private let arrow = HUD.label()
    private let toLabel = HUD.label()
    private let stack: NSStackView
    private var hideTimer: Timer?

    init() {
        stack = NSStackView(views: [fromLabel, arrow, toLabel])
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        // 흐림, 덧칠 색, 글자를 나란히 쌓는다. 흐림만 따로 옅게 할 수 있어야 사용자 지정 불투명도가 판까지 조절한다.
        let content = NSView()
        effect.material = .hudWindow
        effect.state = .active
        tint.wantsLayer = true
        for view in [effect, tint] {
            view.frame = content.bounds
            view.autoresizingMask = [.width, .height]
            content.addSubview(view)
        }

        arrow.stringValue = "→"
        // 폭이 모자라면 '변경 전'만 말줄임하고 '변경 후'는 자르지 않는다.
        fromLabel.lineBreakMode = .byTruncatingTail
        fromLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        toLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
        panel.contentView = content
    }

    // 저장된 표시 위치. 기본값(가운데)은 AppDelegate가 register(defaults:)로 넣는다.
    static var savedPosition: HUDPosition {
        get { HUDPosition(x: UserDefaults.standard.double(forKey: positionXKey), y: UserDefaults.standard.double(forKey: positionYKey)) }
        set {
            UserDefaults.standard.set(newValue.x, forKey: positionXKey)
            UserDefaults.standard.set(newValue.y, forKey: positionYKey)
        }
    }

    // 설정 창 '모양'에서 정한 모양. 없으면 기본 모양.
    static var savedAppearance: HUDAppearance {
        get { HUDAppearance(data: UserDefaults.standard.data(forKey: appearanceKey)) }
        set { UserDefaults.standard.set(newValue.data, forKey: appearanceKey) }
    }

    // 설정 창의 미리보기는 아직 저장하지 않은 위치를 넘긴다. to가 nil이면 바꿀 입력소스가 없다는 뜻으로 "없음"을 흐리게 쓴다.
    func show(from source: InputSourceLabel, to target: InputSourceLabel?, at position: HUDPosition = HUD.savedPosition) {
        // 모양과 색은 외관·손쉬운 사용 설정 변경을 따라가지 않으므로 표시할 때마다 다시 정한다.
        let look = Self.savedAppearance
        let workspace = NSWorkspace.shared
        let colors = look.colors(NSApp.effectiveAppearance.hudMode, reduceTransparency: workspace.accessibilityDisplayShouldReduceTransparency)
        let fromFont = NSFont.systemFont(ofSize: look.scaled(20), weight: look.bold ? .semibold : .medium)  // hud-from
        let toFont = NSFont.systemFont(ofSize: look.scaled(28), weight: look.bold ? .bold : .semibold)     // hud-to
        let (from, to) = look.texts(from: source, to: target)
        fromLabel.stringValue = from
        fromLabel.font = fromFont
        fromLabel.textColor = NSColor(colors.from)
        fromLabel.isHidden = !look.showsFrom
        arrow.isHidden = !look.showsFrom  // 화살표는 변경 전에서 바뀌었다는 뜻이라 변경 전과 함께 숨긴다
        arrow.font = fromFont
        arrow.textColor = NSColor(colors.arrow)
        toLabel.stringValue = to ?? String(localized: "None")
        toLabel.font = to == nil ? fromFont : toFont
        toLabel.textColor = NSColor(to == nil ? colors.from : colors.to)
        tint.layer?.backgroundColor = NSColor(colors.background).cgColor
        effect.alphaValue = colors.blur
        stack.spacing = look.scaled(8)  // space-2
        let v = look.scaled(16)  // 위아래 space-3
        let h = look.isBadge ? Self.badgeInset(content: toLabel.fittingSize, padding: v) : look.scaled(24)  // 좌우 space-4, 약자 배지는 아래
        stack.edgeInsets = NSEdgeInsets(top: v, left: h, bottom: v, right: h)

        var size = panel.contentView!.fittingSize
        let ellipsis = NSAttributedString(string: "…", attributes: [.font: fromFont]).size().width.rounded(.up) + 4
        size.width = look.showsFrom
            ? Self.panelWidth(fitting: size.width, from: fromLabel.fittingSize.width, ellipsis: ellipsis, maxWidth: look.scaled(480))
            : size.width
        // 창 뒤 흐림은 layer cornerRadius로 잘리지 않아 모서리에 네모가 비친다. maskImage로 자르고, 덧칠 색도 따로 둥글린다.
        let radius = look.cornerRadius(height: size.height, standard: 18)  // radius-hud
        effect.maskImage = Self.roundedMask(radius: radius)
        tint.layer?.cornerRadius = radius
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        // 화면은 frame으로 고르고, 자리는 메뉴바·Dock을 뺀 visibleFrame 안에서 정한다.
        if let frame = screen?.visibleFrame {
            panel.setFrame(NSRect(origin: position.origin(size: size, in: frame, margin: Self.screenMargin), size: size), display: true)
        }

        panel.invalidateShadow()  // 그림자를 둥근 모양에 맞춘다.

        // 진행 중인 페이드아웃을 끊고 즉시 다시 보인다.
        NSAnimationContext.runAnimationGroup { $0.duration = 0; panel.animator().alphaValue = 1 }
        panel.orderFrontRegardless()

        hideTimer?.invalidate()
        // '동작 줄이기'가 켜져 있으면 페이드 없이 같은 시점(표시 시간 + 0.3초)에 사라진다.
        let reduceMotion = workspace.accessibilityDisplayShouldReduceMotion
        let duration = UserDefaults.standard.double(forKey: Self.durationKey)
        hideTimer = Timer.scheduledTimer(withTimeInterval: reduceMotion ? duration + Self.fadeDuration : duration, repeats: false) { [weak self] _ in
            guard let self else { return }
            if reduceMotion { self.panel.orderOut(nil) } else { self.fadeOut() }
        }
    }

    // 약자 배지의 좌우 여백. 기본은 위아래와 같은 padding(space-3)이고, 글자가 좁으면 여백을 양쪽에 똑같이 늘려
    // 폭을 높이에 맞춘다. 그래야 정사각형(알약이면 원) 가운데에 글자가 온다.
    static func badgeInset(content: CGSize, padding: CGFloat) -> CGFloat {
        max(padding, ((content.height - content.width) / 2 + padding).rounded())
    }

    // 최대 폭(기본 480pt, 크기 배율을 곱함). 단, '변경 후'가 그보다 길면 '변경 전'이 "…"만 남을 만큼까지는 넓힌다.
    static func panelWidth(fitting: CGFloat, from: CGFloat, ellipsis: CGFloat, maxWidth: CGFloat) -> CGFloat {
        max(min(fitting, maxWidth), fitting - from + ellipsis)
    }

    private func fadeOut() {
        NSAnimationContext.runAnimationGroup({ $0.duration = Self.fadeDuration; panel.animator().alphaValue = 0 }) { [weak self] in
            // 페이드 도중 다시 표시됐다면 alpha가 1로 돌아와 있다.
            guard let self, self.panel.alphaValue == 0 else { return }
            self.panel.orderOut(nil)
        }
    }

    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }

    private static func label() -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.setAccessibilityElement(false)  // 입력소스는 VoiceOver가 이미 읽어 준다.
        return label
    }
}
