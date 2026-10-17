import AppKit

// 메뉴 "설정…"으로 여는 창. 지금은 HUD 표시 시간 한 줄뿐이다. 저장 버튼 없이 바로 적용한다.
final class SettingsWindow: NSObject {
    private static let range = 0.5...5.0
    private static let step = 0.5

    private let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: true)
    private let field = NSTextField()
    private let stepper = NSStepper()
    private let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 1
        return f
    }()

    override init() {
        super.init()
        window.title = "설정"
        window.isReleasedWhenClosed = false
        window.backgroundColor = Tokens.surface

        let body = NSFont.systemFont(ofSize: 13)  // body
        let label = NSTextField(labelWithString: "표시 시간")
        label.font = body
        label.textColor = Tokens.ink

        // NumberFormatter를 붙이면 잘못된 입력에 경고를 띄우므로, 표시에만 쓰고 해석·보정은 직접 한다.
        field.font = body
        field.alignment = .right
        field.cell?.sendsActionOnEndEditing = true  // Return뿐 아니라 포커스 이동에도 적용
        field.target = self
        field.action = #selector(fieldChanged)
        field.widthAnchor.constraint(equalToConstant: 56).isActive = true

        stepper.minValue = Self.range.lowerBound
        stepper.maxValue = Self.range.upperBound
        stepper.increment = Self.step
        stepper.target = self
        stepper.action = #selector(stepperChanged)

        let unit = NSTextField(labelWithString: "초")
        unit.font = body
        unit.textColor = Tokens.ink

        let caption = NSTextField(wrappingLabelWithString: "0.5–5.0초, 0.5초 단위. 사라지는 0.3초는 따로 더해집니다.")
        caption.font = .systemFont(ofSize: 11)  // caption
        caption.textColor = Tokens.muted

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let row = NSStackView(views: [label, spacer, field, stepper, unit])
        row.spacing = 8  // space-2
        let column = NSStackView(views: [row, caption])
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 8  // space-2
        column.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)  // space-3
        column.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.widthAnchor.constraint(equalTo: column.widthAnchor, constant: -32),
            column.widthAnchor.constraint(equalToConstant: 360),
        ])
        window.contentView = column
    }

    func show() {
        apply(UserDefaults.standard.double(forKey: HUD.durationKey))
        window.center()
        NSApp.activate(ignoringOtherApps: true)  // LSUIElement 앱이라 직접 앞으로 가져온다.
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func fieldChanged() {
        // 숫자가 아니면("nan" 포함) 지금 값을 그대로 둔다.
        let typed = formatter.number(from: field.stringValue)?.doubleValue ?? Double(field.stringValue) ?? stepper.doubleValue
        apply(typed.isFinite ? typed : stepper.doubleValue)
    }

    @objc private func stepperChanged() {
        apply(stepper.doubleValue)
    }

    // 0.5 단위로 반올림하고 범위 안으로 넣은 뒤 화면과 UserDefaults에 반영한다.
    private func apply(_ value: Double) {
        let snapped = min(max((value / Self.step).rounded() * Self.step, Self.range.lowerBound), Self.range.upperBound)
        field.stringValue = formatter.string(from: snapped as NSNumber) ?? ""
        stepper.doubleValue = snapped
        UserDefaults.standard.set(snapped, forKey: HUD.durationKey)
    }
}
