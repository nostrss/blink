import AppKit

// "변경 전 → 변경 후"를 마우스가 있는 화면 중앙에 잠깐 띄우는 오버레이. 패널 하나를 재사용한다.
final class HUD {
    static let durationKey = "hudDuration"
    private static let fadeDuration = 0.3

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

    func show(from: String, to: String) {
        fromLabel.stringValue = from
        toLabel.stringValue = to
        // layer 색은 외관 변경을 따라가지 않으므로 표시할 때마다 다시 칠한다.
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            tint.layer?.backgroundColor = Tokens.hudBg.cgColor
        }

        let size = panel.contentView!.fittingSize
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        if let frame = screen?.frame {
            panel.setFrame(NSRect(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2,
                                  width: size.width, height: size.height), display: true)
        }

        // 진행 중인 페이드아웃을 끊고 즉시 다시 보인다.
        panel.invalidateShadow()  // 그림자를 둥근 모양에 맞춘다.

        NSAnimationContext.runAnimationGroup { $0.duration = 0; panel.animator().alphaValue = 1 }
        panel.orderFrontRegardless()

        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: UserDefaults.standard.double(forKey: Self.durationKey), repeats: false) { [weak self] _ in
            self?.fadeOut()
        }
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
        return label
    }
}
