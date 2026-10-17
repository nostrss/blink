import AppKit

// 메뉴 "정보…"와 첫 실행 때 여는 창. 무엇을 하는 앱인지, 지금 켜져 있는지, 어디서 끄는지만 알려 준다.
final class AboutWindow: NSObject {
    private let window = EscClosableWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: true)

    override init() {
        super.init()
        window.title = ""  // 앱 이름은 본문에 쓴다.
        window.isReleasedWhenClosed = false
        window.backgroundColor = Tokens.surface
    }

    func show(firstLaunch: Bool) {
        window.contentView = makeContent(firstLaunch: firstLaunch)
        window.center()
        NSApp.activateForWindow()
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func toggleLoginItem(_ sender: NSButton) {
        LoginItem.set(sender.state == .on)
    }

    @objc private func close() {
        window.close()
    }

    // 상태(켜짐/꺼짐)가 열 때마다 다를 수 있어 매번 새로 만든다.
    private func makeContent(firstLaunch: Bool) -> NSView {
        let isOn = UserDefaults.standard.bool(forKey: AppDelegate.showOnSwitchKey)

        let title = Self.label(firstLaunch ? "Blink에 오신 것을 환영합니다" : "Blink", size: 15, weight: .semibold, color: Tokens.ink)  // title
        let summary = Self.label("입력소스가 바뀌면 화면 중앙에 '변경 전 → 변경 후'를 잠깐 보여 줍니다.", color: Tokens.ink)
        let state = Self.stateCard(isOn: isOn)
        let howTo = Self.label("메뉴바의 키보드 아이콘에서 끄거나 켤 수 있습니다.", color: Tokens.muted)

        var rows: [NSView] = [title, summary, state, howTo]
        if firstLaunch {
            // 기본은 체크 해제. 사용자가 체크해야 로그인 항목에 등록한다.
            let checkbox = NSButton(checkboxWithTitle: "로그인 시 자동 실행", target: self, action: #selector(toggleLoginItem))
            checkbox.font = .systemFont(ofSize: 13)
            checkbox.state = LoginItem.isEnabled ? .on : .off
            rows.append(checkbox)
        }

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let versionLabel = Self.label("버전 \(version)", size: 11, color: Tokens.muted)  // caption
        let button = NSButton(title: firstLaunch ? "시작하기" : "확인", target: self, action: #selector(close))
        button.keyEquivalent = "\r"  // 기본 버튼: 시스템 강조색, Return으로 닫힘
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let foot = NSStackView(views: [versionLabel, spacer, button])
        rows.append(foot)

        let column = NSStackView(views: rows)
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 8  // space-2
        column.setCustomSpacing(12, after: summary)  // 상태 카드 위아래 space-1 추가
        column.setCustomSpacing(12, after: state)
        column.setCustomSpacing(16, after: rows[rows.count - 2])  // 아래 줄 위 space-2 추가
        column.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)  // space-3
        column.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            column.widthAnchor.constraint(equalToConstant: 360),
            summary.widthAnchor.constraint(equalTo: column.widthAnchor, constant: -32),
            state.widthAnchor.constraint(equalTo: column.widthAnchor, constant: -32),
            foot.widthAnchor.constraint(equalTo: column.widthAnchor, constant: -32),
        ])
        return column
    }

    private static func stateCard(isOn: Bool) -> NSView {
        let dot = RoundedView(fill: isOn ? Tokens.signalOn : Tokens.muted, radius: 4)
        dot.widthAnchor.constraint(equalToConstant: 8).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 8).isActive = true

        let text = label(isOn ? "언어 전환 표시 켜짐" : "언어 전환 표시 꺼짐", color: Tokens.ink)
        let row = NSStackView(views: [dot, text])
        row.spacing = 8  // space-2
        row.translatesAutoresizingMaskIntoConstraints = false

        let card = RoundedView(border: Tokens.line, radius: 10)  // radius-md
        card.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),  // space-3
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),  // space-2
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8),
        ])
        return card
    }

    private static func label(_ string: String, size: CGFloat = 13, weight: NSFont.Weight = .regular, color: NSColor) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: string)
        label.font = .systemFont(ofSize: size, weight: weight)  // 기본 13pt = body
        label.textColor = color
        return label
    }
}

// Esc로도 창을 닫는다.
private final class EscClosableWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) {
        close()
    }
}

// 채움·테두리 색을 레이어로 그린다. updateLayer는 현재 외관(라이트/다크)으로 불리므로 색이 따라 바뀐다.
private final class RoundedView: NSView {
    private let fill: NSColor?
    private let border: NSColor?

    init(fill: NSColor? = nil, border: NSColor? = nil, radius: CGFloat) {
        self.fill = fill
        self.border = border
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = radius
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) { fatalError() }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.backgroundColor = fill?.cgColor
        layer?.borderColor = border?.cgColor
        layer?.borderWidth = border == nil ? 0 : 1
    }
}
