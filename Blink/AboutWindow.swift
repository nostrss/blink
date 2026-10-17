import AppKit

// 메뉴 "Blink 정보"로 여는 창. 앱 아이콘, 이름, 버전만 가운데에 보여 준다.
final class AboutWindow: NSObject {
    private let window = ClosableWindow(contentRect: .zero, styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: true)

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
            column.widthAnchor.constraint(equalToConstant: 280),
            icon.widthAnchor.constraint(equalToConstant: 64),
            icon.heightAnchor.constraint(equalToConstant: 64),
        ])
        window.contentView = column
    }

    func show() {
        if !window.isVisible { window.center() }
        NSApp.activateForWindow()
        window.makeKeyAndOrderFront(nil)
    }
}
