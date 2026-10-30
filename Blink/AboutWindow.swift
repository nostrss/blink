import AppKit

// 메뉴 "Blink 정보"로 여는 창. 앱 아이콘, 이름, 버전을 가운데에 두고, 그 아래 지금 버전 이하에서 가장 최근의 새로운 기능을 보여 준다.
// 업데이트한 뒤 첫 실행에도 이 창을 연다.
final class AboutWindow: NSObject {
    private let window = ClosableWindow(contentRect: .zero, styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: true)
    // 노트 줄 아래 버튼과 그 동작. 보일지는 열 때마다 다시 정한다.
    private var actionButtons: [(action: ReleaseNotes.Action, button: NSButton)] = []
    var onEnableTyping: () -> Void = {}
    var typingGranted: () -> Bool = { false }

    override init() {
        super.init()
        window.title = ""
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.closesOnEscape = true
        window.isReleasedWhenClosed = false
        window.backgroundColor = Tokens.surface

        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.setAccessibilityElement(false)  // 바로 아래 이름이 같은 내용을 읽어 준다.
        let name = NSTextField(labelWithString: "Blink")
        name.font = .systemFont(ofSize: 28, weight: .semibold)  // display
        name.textColor = Tokens.ink
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let versionLabel = NSTextField(labelWithString: String(localized: "Version \(version)"))
        versionLabel.font = .systemFont(ofSize: 13)  // body
        versionLabel.textColor = Tokens.muted

        let column = NSStackView(views: [icon, name, versionLabel])
        column.orientation = .vertical
        column.alignment = .centerX
        column.spacing = 4  // space-1
        column.setCustomSpacing(16, after: icon)  // space-3
        // 위는 투명한 제목 막대(28pt) 아래부터 space-3, 좌우·아래는 space-4.
        column.edgeInsets = NSEdgeInsets(top: 28 + 16, left: 24, bottom: 24, right: 24)
        column.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            column.widthAnchor.constraint(equalToConstant: 360),
            icon.widthAnchor.constraint(equalToConstant: 64),
            icon.heightAnchor.constraint(equalToConstant: 64),
        ])

        // 노트가 하나도 없으면 제목과 목록을 빼고 아이콘·이름·버전만 남는다.
        if let notes = ReleaseNotes.latest(upTo: version, notes: ReleaseNotes.all) {
            let heading = NSTextField(labelWithString: String(localized: "New in \(notes.version)"))
            heading.font = .systemFont(ofSize: 15, weight: .semibold)  // title
            heading.textColor = Tokens.ink
            let group = SettingsWindow.group(notes.features.map(row))
            column.addArrangedSubview(heading)
            column.addArrangedSubview(group)
            column.setCustomSpacing(24, after: versionLabel)  // space-4
            column.setCustomSpacing(8, after: heading)  // space-2
            for view in [heading, group] {
                view.widthAnchor.constraint(equalTo: column.widthAnchor, constant: -48).isActive = true
            }
        }
        window.contentView = column
    }

    func show() {
        for (action, button) in actionButtons {
            button.isHidden = !action.isShown(typingGranted: typingGranted())
        }
        window.layoutIfNeeded()
        if !window.isVisible { window.center() }
        NSApp.activateForWindow()
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func act(_ sender: NSButton) {
        switch actionButtons.first(where: { $0.button === sender })?.action {
        case .enableTyping: onEnableTyping()
        case nil: break
        }
    }

    // 왼쪽 accent 심볼, 오른쪽 이름(title)과 설명(body, muted). 위아래 12pt. 동작이 있으면 설명 아래 설명 폭의 accent 버튼.
    private func row(_ feature: ReleaseNotes.Feature) -> NSView {
        let symbol = NSImageView(image: NSImage(systemSymbolName: feature.symbol, accessibilityDescription: nil) ?? NSImage())
        symbol.symbolConfiguration = .init(pointSize: 17, weight: .regular)
        symbol.contentTintColor = Tokens.accent
        let name = NSTextField(labelWithString: feature.title)
        name.font = .systemFont(ofSize: 15, weight: .semibold)  // title
        name.textColor = Tokens.ink
        // 한글을 글자가 아니라 어절에서 끊는다. 텍스트 필드의 lineBreakStrategy는 먹지 않아 문단 스타일로 준다.
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakStrategy = .hangulWordPriority
        let detail = NSTextField(wrappingLabelWithString: "")
        detail.isSelectable = false
        detail.attributedStringValue = NSAttributedString(string: feature.detail, attributes: [
            .font: NSFont.systemFont(ofSize: 13),  // body
            .foregroundColor: Tokens.muted,
            .paragraphStyle: paragraph,
        ])
        let text = NSStackView(views: [name, detail])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 2
        if let action = feature.action {
            let button = NSButton(title: String(localized: "Turn On Typing Statistics"), target: self, action: #selector(act))
            button.bezelStyle = .push
            button.bezelColor = .controlAccentColor
            text.addArrangedSubview(button)
            button.widthAnchor.constraint(equalTo: detail.widthAnchor).isActive = true  // 설명 폭에 꽉 차게
            text.setCustomSpacing(8, after: detail)  // space-2
            actionButtons.append((action, button))
        }
        symbol.translatesAutoresizingMaskIntoConstraints = false
        text.translatesAutoresizingMaskIntoConstraints = false
        // 심볼은 24×20pt 칸 가운데에 두고 이름 줄의 세로 가운데에 맞춘다. 텍스트와는 space-2.
        let row = NSView()
        row.addSubview(symbol)
        row.addSubview(text)
        NSLayoutConstraint.activate([
            text.topAnchor.constraint(equalTo: row.topAnchor, constant: 12),
            text.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -12),
            text.leadingAnchor.constraint(equalTo: symbol.trailingAnchor, constant: 8),  // space-2
            text.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            symbol.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            symbol.centerYAnchor.constraint(equalTo: name.centerYAnchor),
            symbol.widthAnchor.constraint(equalToConstant: 24),
            symbol.heightAnchor.constraint(equalToConstant: 20),
            // 창 360 − 좌우 space-4 − 상자 group-inset 양쪽 − 심볼 칸 24 − space-2
            detail.widthAnchor.constraint(equalToConstant: 360 - 48 - 20 - 24 - 8),
        ])
        return row
    }
}
