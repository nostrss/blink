import AppKit

// 설정 창의 미니 HUD. 실제 HUD와 같은 모양 값으로 '변경 전 → 변경 후'를 작게 그린다.
// 색은 이 뷰의 외관(라이트/다크)을 따르므로, 상위 뷰에 외관을 고정하면 그 모드로 그린다.
final class HUDChip: NSView {
    // 크기 배율을 곱하기 전의 치수.
    struct Style {
        var fromSize: CGFloat
        var toSize: CGFloat
        var height: CGFloat
        var padding: CGFloat
        var gap: CGFloat
        var minWidth: CGFloat
        var maxWidth: CGFloat?  // nil이면 widthLimit만 따른다
        var radius: CGFloat  // 모서리 '기본'일 때
    }

    // '위치'의 미니 모니터용(caption 크기, 높이 24pt, 폭 72–180pt, radius-sm).
    static let mini = Style(fromSize: 11, toSize: 11, height: 24, padding: 8, gap: 4, minWidth: 72, maxWidth: 180, radius: 6)
    // '모양'의 미리보기 칸용. 폭은 칸에 맞춰 widthLimit으로 줄인다.
    static let preview = Style(fromSize: 12, toSize: 17, height: 40, padding: 13, gap: 5, minWidth: 0, maxWidth: nil, radius: 12)

    private let style: Style
    private let stack: NSStackView
    private let from = HUDChip.label()
    private let arrow = HUDChip.label()
    private let to = HUDChip.label()
    private var names: (from: String, to: String?) = ("", nil)

    var look = HUDAppearance() { didSet { refresh() } }
    // 놓일 자리의 폭. 넘치면 실제 HUD처럼 '변경 전'부터 말줄임한다.
    var widthLimit = CGFloat.greatestFiniteMagnitude { didSet { refresh() } }
    private(set) var size = CGSize(width: 96, height: 24)

    init(style: Style) {
        self.style = style
        stack = NSStackView(views: [from, arrow, to])
        super.init(frame: .zero)
        wantsLayer = true
        shadow = NSShadow()
        layer?.shadowOpacity = 0.18
        layer?.shadowRadius = 4
        layer?.shadowOffset = CGSize(width: 0, height: -2)
        arrow.stringValue = "→"
        from.lineBreakMode = .byTruncatingTail
        from.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        to.lineBreakMode = .byTruncatingTail
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        setAccessibilityElement(false)  // 이름은 실제 HUD처럼 VoiceOver가 따로 읽지 않는다.
    }

    required init?(coder: NSCoder) { fatalError() }

    func set(from: String, to: String?) {
        names = (from, to)
        refresh()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refresh()
    }

    // 모양·이름·외관이 바뀔 때마다 글자와 색, 크기를 다시 정한다. 자리는 상위 뷰가 size로 잡는다.
    private func refresh() {
        let reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        let colors = look.colors(effectiveAppearance.hudMode, reduceTransparency: reduce)
        let fromFont = NSFont.systemFont(ofSize: look.scaled(style.fromSize), weight: look.bold ? .semibold : .medium)
        let toFont = NSFont.systemFont(ofSize: look.scaled(style.toSize), weight: look.bold ? .bold : .semibold)
        from.stringValue = names.from
        from.font = fromFont
        from.textColor = NSColor(colors.from)
        from.isHidden = !look.showsFrom
        arrow.font = fromFont
        arrow.textColor = NSColor(colors.arrow)
        to.stringValue = names.to ?? String(localized: "None")
        to.font = names.to == nil ? fromFont : toFont
        to.textColor = NSColor(names.to == nil ? colors.from : colors.to)
        stack.spacing = look.scaled(style.gap)
        let padding = look.scaled(style.padding)
        stack.edgeInsets = NSEdgeInsets(top: 0, left: padding, bottom: 0, right: padding)

        let height = look.scaled(style.height)
        let limit = min(style.maxWidth.map(look.scaled) ?? widthLimit, widthLimit)
        size = CGSize(width: min(max(stack.fittingSize.width, look.scaled(style.minWidth)), limit), height: height)
        layer?.backgroundColor = NSColor(colors.background).cgColor
        layer?.cornerRadius = look.cornerRadius(height: height, standard: style.radius)
    }

    private static func label() -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.setAccessibilityElement(false)
        return label
    }
}
