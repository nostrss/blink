import AppKit

// "변경 전 → 변경 후"를 마우스가 있는 화면의 표시 위치에 잠깐 띄우는 오버레이. 패널 하나를 재사용한다.
final class HUD {
    static let durationKey = "hudDuration"
    static let positionXKey = "hudPositionX"
    static let positionYKey = "hudPositionY"
    private static let screenMargin: CGFloat = 24  // space-4
    private static let fadeDuration = 0.3
    private static let maxWidth: CGFloat = 480

    private let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
    private let tint = NSView()
    private let fromLabel = HUD.label(size: 20, weight: .medium, color: Tokens.muted)   // hud-from
    private let toLabel = HUD.label(size: 28, weight: .semibold, color: Tokens.hudInk)  // hud-to
    private var hideTimer: Timer?

    init() {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.state = .active
        // 창 뒤 흐림은 layer cornerRadius로 잘리지 않아 모서리에 네모가 비친다. maskImage로 자른다.
        effect.maskImage = HUD.roundedMask(radius: 18)  // radius-hud

        tint.wantsLayer = true
        tint.layer?.cornerRadius = 18  // maskImage는 흐림만 자르므로 덧칠 색도 따로 둥글린다.
        tint.frame = effect.bounds
        tint.autoresizingMask = [.width, .height]
        effect.addSubview(tint)

        let arrow = HUD.label(size: 20, weight: .medium, color: Tokens.accent)
        arrow.stringValue = "→"
        // 폭이 모자라면 '변경 전'만 말줄임하고 '변경 후'는 자르지 않는다.
        fromLabel.lineBreakMode = .byTruncatingTail
        fromLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        toLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        let stack = NSStackView(views: [fromLabel, arrow, toLabel])
        stack.spacing = 8  // space-2
        stack.alignment = .centerY
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 24, bottom: 16, right: 24)  // 좌우 space-4, 위아래 space-3
        stack.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            stack.topAnchor.constraint(equalTo: effect.topAnchor),
            stack.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
        ])
        panel.contentView = effect
    }

    // 저장된 표시 위치. 기본값(가운데)은 AppDelegate가 register(defaults:)로 넣는다.
    static var savedPosition: HUDPosition {
        get { HUDPosition(x: UserDefaults.standard.double(forKey: positionXKey), y: UserDefaults.standard.double(forKey: positionYKey)) }
        set {
            UserDefaults.standard.set(newValue.x, forKey: positionXKey)
            UserDefaults.standard.set(newValue.y, forKey: positionYKey)
        }
    }

    // 설정 창의 미리보기는 아직 저장하지 않은 위치를 넘긴다.
    func show(from: String, to: String, at position: HUDPosition = HUD.savedPosition) {
        fromLabel.stringValue = from
        toLabel.stringValue = to
        // layer 색은 외관·손쉬운 사용 설정 변경을 따라가지 않으므로 표시할 때마다 다시 칠한다.
        // '투명도 줄이기'가 켜져 있으면 불투명 surface로 칠한다.
        let workspace = NSWorkspace.shared
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            let bg = workspace.accessibilityDisplayShouldReduceTransparency ? Tokens.surface : Tokens.hudBg
            tint.layer?.backgroundColor = bg.cgColor
        }

        var size = panel.contentView!.fittingSize
        let ellipsis = NSAttributedString(string: "…", attributes: [.font: fromLabel.font!]).size().width.rounded(.up) + 4
        size.width = Self.panelWidth(fitting: size.width, from: fromLabel.fittingSize.width, ellipsis: ellipsis)
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

    // 최대 480pt. 단, '변경 후'가 그보다 길면 '변경 전'이 "…"만 남을 만큼까지는 넓힌다.
    static func panelWidth(fitting: CGFloat, from: CGFloat, ellipsis: CGFloat) -> CGFloat {
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

    private static func label(size: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.setAccessibilityElement(false)  // 입력소스는 VoiceOver가 이미 읽어 준다.
        return label
    }
}
