import AppKit

// 입력 통계를 세고(StatsRecorder) 보여 주는(메뉴 카드, 통계 창) AppKit 층. 계산은 Statistics.swift에 있다.

// 전환·포인터 이벤트를 받아 StatsLog에 더하고 파일에 저장한다. 포인터 이벤트는 손쉬운 사용 권한 없이 받을 수 있다.
final class StatsRecorder {
    static let enabledKey = "collectStatistics"
    // 타이핑 통계(기본 꺼짐). 켜면 입력 모니터링 권한을 묻고, 허용된 동안만 리슨 전용 이벤트 탭으로 키 개수를 센다.
    static let typingKey = "collectTyping"
    // 권한을 허용하거나 거둬 타이핑 통계 상태가 바뀌면 보낸다(설정 창·메뉴가 다시 읽는다).
    static let typingStateChanged = Notification.Name("StatsRecorder.typingStateChanged")
    private static let saveInterval: TimeInterval = 900

    private var log = StatsLog()
    // 포인터 이벤트는 1초에 수백 번 오므로 지금 시간 칸의 합계만 메모리에 더하고, 칸이 바뀌거나 읽을 때 기록에 넣는다.
    private var pending = StatsCounts()
    private var pendingApps: [String: [String: Double]] = [:]
    private var pendingHourEnd = Date.distantPast
    private var meter = PointerMeter()
    // 마지막으로 포인터가 있던 화면과 그 화면의 mm/pt. 화면 구성이 바뀌면 지운다.
    private var screenScale: (frame: NSRect, millimetersPerPoint: Double)?
    private var monitors: [Any] = []
    private var saveTimer: Timer?
    private let file: URL
    // 마지막으로 파일에 쓴(또는 읽은) 기록. 같으면 다시 쓰지 않는다.
    private var savedLog = StatsLog()

    var isEnabled: Bool { UserDefaults.standard.bool(forKey: Self.enabledKey) }
    var typingEnabled: Bool { UserDefaults.standard.bool(forKey: Self.typingKey) }
    var typingGranted: Bool { CGPreflightListenEventAccess() }
    var typingState: TypingState { TypingState.of(enabled: typingEnabled, granted: typingGranted) }
    // 키를 누른 순간의 입력소스 ID. AppDelegate가 정한다.
    var currentSource: () -> String? = { nil }

    private var tap: CFMachPort?
    private var tapSource: CFRunLoopSource?
    private var typingMeter = TypingMeter()
    // 권한을 기다리는 동안 1초마다 다시 본다(허용은 시스템 설정에서 하므로 알림이 없다).
    private var permissionTimer: Timer?
    private var lastTypingState: TypingState?

    init(file: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Statistics.json")) {
        self.file = file
        guard let data = try? Data(contentsOf: file) else { return }
        do {
            log = try JSONDecoder().decode(StatsLog.self, from: data)
            savedLog = log
        } catch {
            // 읽지 못한 기록을 빈 기록으로 덮어쓰지 않도록 시각을 붙인 이름으로 옆에 옮겨 둔다.
            NSLog("통계 기록을 읽지 못함: %@", error.localizedDescription)
            let backup = file.deletingPathExtension().appendingPathExtension("unreadable-\(Int(Date().timeIntervalSince1970)).json")
            do {
                try FileManager.default.moveItem(at: file, to: backup)
            } catch {
                NSLog("통계 기록을 옮기지 못해 저장하지 않음: %@", error.localizedDescription)
                canSave = false
            }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            self?.screenScale = nil
        }
    }

    private var canSave = true

    var snapshot: StatsLog {
        flush()
        return log
    }

    // '통계 모으기'에 맞춰 이벤트 감시를 켜고 끈다. 끄면 그때까지 센 것을 저장한다.
    func reload() {
        if isEnabled { start() } else { stop() }
        reloadTyping()
    }

    // 타이핑 통계 스위치를 바꾼다. 켤 때 권한이 없으면 묻는다(처음 한 번만 시스템 창이 뜬다).
    func setTyping(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Self.typingKey)
        if enabled, !typingGranted { CGRequestListenEventAccess() }
        reloadTyping()
    }

    // 모으기·타이핑 스위치와 권한에 맞춰 탭을 켜고 끈다. 끄면 탭을 바로 내린다.
    func reloadTyping() {
        let state = typingState
        if isEnabled, state == .on { startTyping() } else { stopTyping() }
        if isEnabled, typingEnabled, state == .denied { waitForPermission() } else { permissionTimer?.invalidate(); permissionTimer = nil }
        if state != lastTypingState {
            lastTypingState = state
            NotificationCenter.default.post(name: Self.typingStateChanged, object: self)
        }
    }

    private func waitForPermission() {
        guard permissionTimer == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, self.typingGranted else { return }
            self.reloadTyping()
        }
        RunLoop.main.add(timer, forMode: .common)
        permissionTimer = timer
    }

    private func startTyping() {
        guard tap == nil else { return }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .listenOnly, eventsOfInterest: mask,
                                          callback: { _, type, event, info in
                                              if let info { Unmanaged<StatsRecorder>.fromOpaque(info).takeUnretainedValue().handleKey(type, event) }
                                              return Unmanaged.passUnretained(event)
                                          }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        else {
            NSLog("타이핑 통계 이벤트 탭을 만들지 못함")
            return
        }
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        tapSource = source
    }

    private func stopTyping() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let tapSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), tapSource, .commonModes) }
        CFMachPortInvalidate(tap)
        self.tap = nil
        tapSource = nil
        typingMeter = TypingMeter()
    }

    // 키 코드는 읽지 않는다. 반복인지만 보고, 개수와 그때의 입력소스·앱만 더한다.
    private func handleKey(_ type: CGEventType, _ event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        guard type == .keyDown, Keystroke.counts(isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0) else { return }
        let source = currentSource() ?? "?"
        add(.keystroke(source: source, typingTime: typingMeter.press(at: Double(event.timestamp) / 1_000_000_000)))
        let app = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "?"
        pendingApps[app, default: [:]][source, default: 0] += 1
    }

    func countSwitch() {
        guard isEnabled else { return }
        add(StatsCounts(switches: 1))
    }

    func clear() {
        log = StatsLog()
        pending = StatsCounts()
        pendingApps = [:]
        save()
    }

    func save() {
        flush()
        log.prune(now: Date())
        guard canSave, log != savedLog else { return }
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(log).write(to: file, options: .atomic)
            savedLog = log
        } catch {
            NSLog("통계 기록을 저장하지 못함: %@", error.localizedDescription)
        }
    }

    private func add(_ counts: StatsCounts) {
        let now = Date()
        if now >= pendingHourEnd {
            flush()
            pendingHourEnd = Calendar.current.dateInterval(of: .hour, for: now)?.end ?? now
        }
        pending.add(counts)
    }

    // 모아 둔 지금 칸의 합계를 기록에 넣는다. 칸 안의 시각이면 되므로 칸이 끝나기 1초 전으로 둔다.
    private func flush() {
        guard pending != StatsCounts() else { return }
        let date = pendingHourEnd.addingTimeInterval(-1)
        log.add(pending, at: date, calendar: .current)
        log.addApps(pendingApps, at: date, calendar: .current)
        pending = StatsCounts()
        pendingApps = [:]
    }

    private func start() {
        guard monitors.isEmpty else { return }
        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
                                             .leftMouseDown, .rightMouseDown, .scrollWheel]
        // 다른 앱 위의 이벤트는 전역 감시, Blink 창 위의 이벤트는 로컬 감시로 받는다.
        if let global = NSEvent.addGlobalMonitorForEvents(matching: events, handler: { [weak self] in self?.handle($0) }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: events, handler: { [weak self] in self?.handle($0); return $0 }) {
            monitors.append(local)
        }
        let timer = Timer(timeInterval: Self.saveInterval, repeats: true) { [weak self] _ in self?.save() }
        timer.tolerance = 60
        RunLoop.main.add(timer, forMode: .common)
        saveTimer = timer
    }

    private func stop() {
        guard !monitors.isEmpty else { return }
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        saveTimer?.invalidate()
        saveTimer = nil
        meter = PointerMeter()
        save()
    }

    private func handle(_ event: NSEvent) {
        let mouse = NSEvent.mouseLocation
        switch event.type {
        case .leftMouseDown, .rightMouseDown:
            // ⌃클릭은 macOS에서 오른쪽 클릭이다.
            let left = event.type == .leftMouseDown && !event.modifierFlags.contains(.control)
            add(.click(left: left, clickCount: event.clickCount))
        case .scrollWheel:
            var counts = StatsCounts()
            counts.scroll = PointerMeter.scrollPoints(dx: event.scrollingDeltaX, dy: event.scrollingDeltaY, precise: event.hasPreciseScrollingDeltas)
                * millimetersPerPoint(at: mouse)
            if counts.scroll > 0 { add(counts) }
        default:
            let counts = meter.move(to: mouse, at: event.timestamp, millimetersPerPoint: millimetersPerPoint(at: mouse))
            if counts.distance > 0 || counts.movingTime > 0 { add(counts) }
        }
    }

    // 포인터가 있는 화면의 실제 크기로 포인트를 mm로 바꾼다. 같은 화면 안이면 지난 값을 쓴다.
    private func millimetersPerPoint(at point: NSPoint) -> Double {
        if let screenScale, NSMouseInRect(point, screenScale.frame, false) { return screenScale.millimetersPerPoint }
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) }) ?? NSScreen.main,
              let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        else { return PointerMeter.millimetersPerPoint(physicalWidth: 0, pointWidth: 0) }
        let scale = PointerMeter.millimetersPerPoint(physicalWidth: CGDisplayScreenSize(id).width, pointWidth: screen.frame.width)
        screenScale = (screen.frame, scale)
        return scale
    }
}

private func label(_ text: String = "", size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = Tokens.muted) -> NSTextField {
    let label = NSTextField(labelWithString: text)
    label.font = .systemFont(ofSize: size, weight: weight)
    label.textColor = color
    return label
}

// 큰 숫자(display, 고정폭 숫자). 횟수는 단위('회')를 body, muted로 붙인다.
private final class BigNumberView: NSTextField {
    private static let number: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 28, weight: .semibold),  // display
                                                                .foregroundColor: Tokens.ink]
    private static let unit: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: Tokens.muted]  // body

    init() {
        super.init(frame: .zero)
        isEditable = false
        isSelectable = false
        isBordered = false
        drawsBackground = false
    }

    required init?(coder: NSCoder) { fatalError() }

    func show(_ text: String) {
        attributedStringValue = NSAttributedString(string: text, attributes: Self.number)
    }

    // 단위의 꼴과 자리는 언어마다 달라("86회", "86 times", "86 раз") 숫자를 넣은 문장으로 받고, 숫자만 크게 칠한다.
    // 문장 속 숫자는 지역 설정대로 자릿수를 묶어 들어온다(1,240).
    func show(count value: Double) {
        let text = NSMutableAttributedString(string: String(localized: "\(Int(value.rounded())) times"), attributes: Self.unit)
        let range = (text.string as NSString).range(of: StatsFormat.count(value, locale: .current))
        if range.location != NSNotFound { text.setAttributes(Self.number, range: range) }
        attributedStringValue = text
    }
}

// 전환·키 입력 막대. 높이 48pt(메뉴 카드는 28pt), accent 막대, line 바닥선. VoiceOver는 이미지 하나로 읽는다.
final class StatsBarsView: NSView {
    private static let gap: CGFloat = 2
    private let height: CGFloat

    var values: [Double] = [] { didSet { needsDisplay = true } }

    init(height: CGFloat = 48) {
        self.height = height
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: height + 1) }

    override func draw(_ dirtyRect: NSRect) {
        Tokens.line.setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: 1).fill()
        guard !values.isEmpty else { return }
        let width = (bounds.width - Self.gap * CGFloat(values.count - 1)) / CGFloat(values.count)
        Tokens.accent.setFill()
        for (index, height) in StatsBars.heights(values, height: height).enumerated() where height > 0 {
            let rect = NSRect(x: CGFloat(index) * (width + Self.gap), y: 1, width: width, height: height)
            NSBezierPath(roundedRect: rect, xRadius: 1.5, yRadius: 1.5).fill()
            NSRect(x: rect.minX, y: 1, width: width, height: min(height, 1.5)).fill()  // 아래 모서리는 각지게
        }
    }
}

// 막대 아래 눈금. 7일은 막대마다 하나씩, 나머지는 양 끝에 맞춰 고르게 둔다. 7일·30일의 마지막('오늘')은 accent.
private final class StatsAxisView: NSStackView {
    func show(_ period: StatsPeriod, now: Date) {
        let labels = period.axisLabels(now: now, calendar: .current, locale: .current)
        setViews(labels.enumerated().map { index, text in
            let field = label(text, size: 11)  // caption
            if period != .today, index == labels.count - 1 {
                field.textColor = Tokens.accent
                field.font = .systemFont(ofSize: 11, weight: .semibold)
            }
            field.alignment = .center
            return field
        }, in: .leading)
        distribution = period == .week ? .fillEqually : .equalSpacing
        setAccessibilityElement(false)
    }
}

// 값 글자: 앞의 숫자 부분만 굵게(고정폭 숫자, ink), 나머지 단위는 작게 muted. "128회", "1.33 km", "86 times".
private func valueText(_ text: String, size: CGFloat, unitSize: CGFloat = 13, color: NSColor = Tokens.ink) -> NSAttributedString {
    let result = NSMutableAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: unitSize), .foregroundColor: Tokens.muted])
    if let range = text.range(of: "[0-9][0-9.,\u{00A0}\u{202F}' ]*[0-9]|[0-9]", options: .regularExpression) {
        result.setAttributes([.font: NSFont.monospacedDigitSystemFont(ofSize: size, weight: .semibold), .foregroundColor: color],
                             range: NSRange(range, in: text))
    }
    return result
}

private func countText(_ value: Double) -> String { String(localized: "\(Int(value.rounded())) times") }

private func perMinuteText(_ value: Double) -> String { String(localized: "\(Int(value.rounded())) per minute") }

// 입력소스의 순위별 색: source-1·2·3, 나머지는 source-other.
private func sourceColor(_ rank: Int?) -> NSColor {
    switch rank {
    case 0: Tokens.source1
    case 1: Tokens.source2
    case 2: Tokens.source3
    default: Tokens.sourceOther
    }
}

private func fixedSize(_ view: NSView, _ width: CGFloat, _ height: CGFloat) -> NSView {
    view.translatesAutoresizingMaskIntoConstraints = false
    view.widthAnchor.constraint(equalToConstant: width).isActive = true
    view.heightAnchor.constraint(equalToConstant: height).isActive = true
    return view
}

private func hstack(_ views: [NSView], spacing: CGFloat = 6, alignment: NSLayoutConstraint.Attribute = .firstBaseline) -> NSStackView {
    let row = NSStackView(views: views)
    row.spacing = spacing
    row.alignment = alignment
    return row
}

private func spacer() -> NSView {
    let view = NSView()
    view.setContentHuggingPriority(.init(1), for: .horizontal)
    return view
}

private final class ColorView: NSView {
    var color: NSColor { didSet { needsDisplay = true } }
    private let radius: CGFloat

    init(_ color: NSColor, radius: CGFloat) {
        self.color = color
        self.radius = radius
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        color.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius).fill()
    }
}

private func line() -> NSView { ColorView(Tokens.line, radius: 0) }

// 가로로 쌓은 비율 막대. 칸 사이 2pt 틈, 양 끝 둥글게. length: 전체 폭 중 막대가 차지하는 비율(앱별 막대).
private final class StackBarView: NSView {
    var segments: [(value: Double, color: NSColor)] = [] { didSet { needsDisplay = true } }
    var length = 1.0 { didSet { needsDisplay = true } }
    private let radius: CGFloat

    init(height: CGFloat, radius: CGFloat) {
        self.radius = radius
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: height).isActive = true
        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let total = segments.reduce(0) { $0 + $1.value }
        guard total > 0 else { return }
        let full = bounds.width * length
        let shown = segments.filter { $0.value > 0 }
        let gaps = CGFloat(shown.count - 1) * 2
        NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: full, height: bounds.height), xRadius: radius, yRadius: radius).addClip()
        var x: CGFloat = 0
        for segment in shown {
            let width = max(0, full - gaps) * segment.value / total
            segment.color.setFill()
            NSRect(x: x, y: 0, width: width, height: bounds.height).fill()
            x += width + 2
        }
    }
}

// 켜기 유도 그림: 작은 키보드(키 하나가 accent) 위로 막대 다섯 개. 92×70 기준으로 그리고 크기에 맞춰 줄인다.
private final class TypingIllustrationView: NSView {
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let scale = bounds.width / 92
        NSGraphicsContext.current?.cgContext.scaleBy(x: scale, y: scale)
        func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat, _ color: NSColor) {
            color.setFill()
            NSBezierPath(roundedRect: NSRect(x: x, y: y, width: w, height: h), xRadius: r, yRadius: r).fill()
        }
        for (index, (y, alpha)) in [(26.0, 0.45), (18, 0.6), (8, 1), (14, 0.75), (22, 1)].enumerated() {
            rect(18 + CGFloat(index) * 12, y, 8, 36 - y, 1.5, index == 4 ? Tokens.source2 : Tokens.accent.withAlphaComponent(alpha))
        }
        rect(6, 40, 80, 26, 5, Tokens.line)
        rect(7, 41, 78, 24, 4.5, Tokens.groupBackground)
        for (row, (start, count)) in [(10.0, 8), (13, 7), (20, 5)].enumerated() {
            for key in 0..<count {
                let lit = row == 1 && key == 3
                rect(start + CGFloat(key) * 9.5, 45 + CGFloat(row) * 7, 8, 5, 1.2, lit ? Tokens.accent : Tokens.line)
            }
        }
    }
}

// 타이핑 통계가 꺼져 있거나 권한이 없을 때 타이핑 자리에 두는 카드. 꺼짐·끈 뒤는 같은 카드, 거부면 문구와 버튼만 바뀐다.
// compact: 메뉴 요약 카드용(작은 그림, 제목과 버튼만).
final class TypingPromoView: NSView {
    private let compact: Bool
    private let title: NSTextField
    private let detail: NSTextField
    private let privacy: NSTextField
    private let button = NSButton(title: "", target: nil, action: nil)
    private var state = TypingState.off
    var onEnable: () -> Void = {}
    var onOpenSystemSettings: () -> Void = {}

    init(compact: Bool, textWidth: CGFloat) {
        self.compact = compact
        title = NSTextField(wrappingLabelWithString: "")
        detail = NSTextField(wrappingLabelWithString: "")
        privacy = NSTextField(wrappingLabelWithString: "")
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 10  // radius-md
        layer?.borderWidth = 1
        title.font = .systemFont(ofSize: compact ? 13 : 14, weight: .semibold)
        title.textColor = Tokens.ink
        detail.font = .systemFont(ofSize: 13)
        detail.textColor = Tokens.ink
        privacy.font = .systemFont(ofSize: 11)  // caption
        privacy.textColor = Tokens.muted
        privacy.stringValue = String(localized: "Blink counts only how many keys you press, never what you type. Requires Input Monitoring permission.")
        detail.stringValue = String(localized: "Turn on typing statistics to see your keystrokes and speed, by input source and by app.")
        for field in [title, detail, privacy] {
            field.isSelectable = false
            field.preferredMaxLayoutWidth = textWidth
        }
        button.bezelStyle = .push
        button.controlSize = compact ? .small : .regular
        button.bezelColor = .controlAccentColor
        button.target = self
        button.action = #selector(act)
        let text = NSStackView(views: compact ? [title, button] : [title, detail, privacy, button])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 4
        text.setCustomSpacing(8, after: compact ? title : privacy)
        let illustration = compact ? fixedSize(TypingIllustrationView(), 60, 46) : fixedSize(TypingIllustrationView(), 92, 70)
        let row = NSStackView(views: [illustration, text])
        row.alignment = .centerY
        row.spacing = compact ? 10 : 14
        row.edgeInsets = compact ? NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10) : NSEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor), row.bottomAnchor.constraint(equalTo: bottomAnchor),
            row.leadingAnchor.constraint(equalTo: leadingAnchor), row.trailingAnchor.constraint(equalTo: trailingAnchor),
            text.widthAnchor.constraint(equalToConstant: textWidth),
        ])
        show(.off)
    }

    required init?(coder: NSCoder) { fatalError() }

    func show(_ state: TypingState) {
        self.state = state
        let denied = state == .denied
        title.stringValue = denied ? String(localized: "Input Monitoring permission is off")
            : String(localized: "Curious how many keys you pressed today?")
        detail.stringValue = denied ? String(localized: "Turn on Blink in System Settings › Privacy & Security › Input Monitoring to start counting.")
            : String(localized: "Turn on typing statistics to see your keystrokes and speed, by input source and by app.")
        privacy.isHidden = denied
        button.title = denied ? String(localized: "Open System Settings…") : String(localized: "Turn On Typing Statistics")
    }

    // 엷은 accent 배경과 테두리. CGColor라 외관이 바뀔 때 다시 칠한다.
    override func updateLayer() {
        layer?.backgroundColor = Tokens.accent.withAlphaComponent(0.1).cgColor
        layer?.borderColor = Tokens.accent.withAlphaComponent(0.35).cgColor
    }

    override var wantsUpdateLayer: Bool { true }

    @objc private func act() {
        if state == .denied { onOpenSystemSettings() } else { onEnable() }
    }
}

// 입력소스별 줄: 색 칸, 이름 옆 작은 %, (통계 창은 키 입력 수), 분당 키 입력과 라틴 문자면 WPM 둘째 줄.
// sources: 저장된 ID를 지금 언어의 이름과 첫 언어(WPM)로 바꾼다.
private func sourceRow(_ share: StatsShare, rank: Int, perMinute: Double?, sources: [String: InputSourceInfo], swatch: CGFloat, count: Bool) -> NSView {
    let name = share.name.map { TypingFormat.sourceName(id: $0, in: sources) } ?? String(localized: "\(share.otherCount) others")
    let showsWPM = share.name.map { TypingFormat.showsWPM(language: sources[$0]?.language) } ?? false
    // 이름 옆에 작은 %. 한 줄로 두고, 길면 가운데를 줄여 이름 앞부분과 %가 둘 다 남게 한다.
    let nameText = NSMutableAttributedString(string: name, attributes: [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: Tokens.ink])
    nameText.append(NSAttributedString(string: " \(share.percent)%", attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: Tokens.muted]))
    let truncating = NSMutableParagraphStyle()
    truncating.lineBreakMode = .byTruncatingMiddle  // 서식 있는 글자는 칸의 lineBreakMode를 따르지 않아 글자에 직접 준다
    nameText.addAttribute(.paragraphStyle, value: truncating, range: NSRange(location: 0, length: nameText.length))
    let nameField = NSTextField(labelWithAttributedString: nameText)
    nameField.lineBreakMode = .byTruncatingMiddle
    nameField.usesSingleLineMode = true
    nameField.maximumNumberOfLines = 1
    nameField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    let right = NSStackView()
    right.orientation = .vertical
    right.alignment = .trailing
    right.spacing = 0
    if let perMinute {
        let speed = label(perMinuteText(perMinute), size: 13, color: Tokens.ink)
        speed.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        right.addArrangedSubview(speed)
        if showsWPM { right.addArrangedSubview(label(String(localized: "\(TypingFormat.wpm(perMinute: perMinute)) WPM"), size: 11)) }
    }
    // 색 칸은 첫 줄(13pt 글자 한 줄 높이) 세로 가운데에 둔다. 둘째 줄(WPM)이 있어도 첫 줄에 맞춘다.
    let swatchView = fixedSize(ColorView(sourceColor(rank), radius: 2), swatch, swatch)
    let swatchBox = fixedSize(NSView(), swatch, ceil(nameField.intrinsicContentSize.height))
    swatchBox.addSubview(swatchView)
    NSLayoutConstraint.activate([swatchView.centerYAnchor.constraint(equalTo: swatchBox.centerYAnchor),
                                 swatchView.leadingAnchor.constraint(equalTo: swatchBox.leadingAnchor)])
    var views: [NSView] = [swatchBox, nameField, spacer()]
    if count {
        let keys = label(countText(share.value), size: 13)
        keys.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        views.append(keys)
        keys.widthAnchor.constraint(greaterThanOrEqualToConstant: 76).isActive = true
        keys.alignment = .right
        right.widthAnchor.constraint(greaterThanOrEqualToConstant: 96).isActive = true
    }
    views.append(right)
    return hstack(views, alignment: .top)
}

// 메뉴 맨 위 요약 카드: 오늘의 전환·타이핑·포인터 핵심 숫자. 누를 수 있는 것은 켜기 버튼뿐이다(NSMenuItem.view).
final class StatsCardView: NSView {
    static let width: CGFloat = 300
    // 메뉴 항목 글자와 같은 줄에서 시작한다.
    static let inset: CGFloat = 14
    private static let content = width - 2 * inset

    private let stack = NSStackView()
    private let switchBars = StatsBarsView(height: 28)
    let promo = TypingPromoView(compact: true, textWidth: StatsCardView.content - 20 - 60 - 10)

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: Self.width, height: 0))
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 7
        stack.edgeInsets = NSEdgeInsets(top: 8, left: Self.inset, bottom: 10, right: Self.inset)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.widthAnchor.constraint(equalToConstant: Self.width),
        ])
        switchBars.setAccessibilityLabel(String(localized: "Switches per hour"))
    }

    required init?(coder: NSCoder) { fatalError() }

    // 이름표 바로 옆에 작은 증감, 굵은 값은 오른쪽 끝.
    private func row(_ title: String, _ change: StatsChange?, _ value: String) -> NSView {
        var views: [NSView] = [label(title, size: 13, color: Tokens.ink)]
        if let change, !change.arrow.isEmpty { views.append(label(change.arrow, size: 11)) }
        views += [spacer(), NSTextField(labelWithAttributedString: valueText(value, size: 15))]
        return hstack(views)
    }

    // sources: 켜진 입력소스(ID → 이름·첫 언어). 전환 이름(한/영·입력소스), 입력소스 이름, WPM을 정한다.
    func reload(_ log: StatsLog, typing: TypingState, sources: [String: InputSourceInfo]) {
        let now = Date()
        let summary = StatsSummary(log: log, period: .today, now: now, calendar: .current)
        let (current, previous) = (summary.current, summary.previous)
        switchBars.values = summary.bars
        var views: [NSView] = [
            label(String(localized: "Today"), size: 13, weight: .semibold, color: Tokens.ink),
            row(TypingFormat.switchesTitle(sourceCount: sources.count), .between(current.switches, previous.switches), countText(current.switches)),
            switchBars,  // 막대 바닥선이 구분선을 겸한다
        ]
        if typing == .on {
            let perMinute = TypingFormat.perMinute(keystrokes: current.keystrokes, seconds: current.typingTime)
            let before = TypingFormat.perMinute(keystrokes: previous.keystrokes, seconds: previous.typingTime)
            views += [row(String(localized: "Keystrokes"), .between(current.keystrokes, previous.keystrokes), countText(current.keystrokes)),
                      row(String(localized: "Keys per Minute"), .between(perMinute, before), countText(perMinute))]
            let shares = StatsShare.rows(current.sourceKeystrokes, limit: 3)
            if !shares.isEmpty {
                let bar = StackBarView(height: 8, radius: 4)
                bar.segments = shares.enumerated().map { ($1.value, sourceColor($1.name == nil ? nil : $0)) }
                views.append(bar)
                for (rank, share) in shares.enumerated() {
                    let speed = share.name.map { TypingFormat.perMinute(keystrokes: current.sourceKeystrokes[$0] ?? 0, seconds: current.sourceTypingTime[$0] ?? 0) }
                    views.append(sourceRow(share, rank: share.name == nil ? 3 : rank, perMinute: speed,
                                           sources: sources, swatch: 8, count: false))
                }
            }
        } else {
            promo.show(typing)
            views.append(promo)
        }
        views += [line(),
                  row(String(localized: "Pointer Distance"), .between(current.distance, previous.distance),
                      StatsFormat.distance(millimeters: current.distance, locale: .current)),
                  row(String(localized: "Clicks"), nil, countText(current.clicks))]
        stack.setViews(views, in: .leading)
        for view in views where view !== views[0] {
            view.widthAnchor.constraint(equalToConstant: Self.content).isActive = true
            if view is ColorView { view.heightAnchor.constraint(equalToConstant: 1).isActive = true }
        }
        stack.setCustomSpacing(4, after: views[1])
        // 켜기 카드의 줄바꿈 글자는 폭이 정해진 뒤에야 높이가 맞으므로 한 번 배치한 뒤 다시 잰다.
        for _ in 0..<2 {
            layoutSubtreeIfNeeded()
            setFrameSize(NSSize(width: Self.width, height: stack.fittingSize.height))
        }
    }
}

// 포인터 숫자 칸 하나: 라벨, 값, 아래 줄(증감 또는 클릭 내역).
private final class StatsTileView: NSView {
    let value = BigNumberView()
    let detail = label(size: 11)  // caption

    init(_ title: String) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 10  // radius-md
        layer?.borderWidth = 1
        let stack = NSStackView(views: [label(title, size: 11), value, detail])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        detail.lineBreakMode = .byTruncatingTail
    }

    required init?(coder: NSCoder) { fatalError() }

    // 테두리(line)는 CGColor라 외관이 바뀔 때 다시 칠한다.
    override func updateLayer() {
        layer?.borderColor = Tokens.line.cgColor
    }

    override var wantsUpdateLayer: Bool { true }
}

// 메뉴 '통계…'로 여는 창. 오늘 · 7일 · 30일 기간을 골라 전환 횟수와 포인터 사용량을 본다.
final class StatsWindow: NSObject {
    private static let width: CGFloat = 480
    static let refreshInterval: TimeInterval = 2  // 메뉴 카드도 열려 있는 동안 같은 간격으로 새로 읽는다

    private let window = ClosableWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: true)
    private let recorder: StatsRecorder
    private let segments = NSSegmentedControl()
    private let switches = BigNumberView()
    private let switchesChange = label(size: 13)  // body
    private let bars = StatsBarsView()
    private let axis = StatsAxisView()
    private let distance = StatsTileView(String(localized: "Distance"))
    private let speed = StatsTileView(String(localized: "Average Speed"))
    private let clicks = StatsTileView(String(localized: "Clicks"))
    private let scroll = StatsTileView(String(localized: "Scrolling"))
    private let keystrokes = StatsTileView(String(localized: "Keystrokes"))
    private let perMinute = StatsTileView(String(localized: "Keys per Minute"))
    private let typingBars = StatsBarsView()
    private let typingAxis = StatsAxisView()
    // 타이핑 구역의 입력소스별·앱별 줄. 읽을 때마다 새로 채운다.
    private let typingDetail = NSStackView()
    private let typingOn = NSStackView()
    let promo = TypingPromoView(compact: false, textWidth: 480 - 32 - 28 - 92 - 14)
    private let switchesTitle = label(size: 11)  // caption
    // 켜진 입력소스(ID → 이름·첫 언어). AppDelegate가 정한다.
    private let sources: () -> [String: InputSourceInfo]
    private var timer: Timer?
    private let scrollView = NSScrollView()
    private var column = NSStackView()

    init(recorder: StatsRecorder, sources: @escaping () -> [String: InputSourceInfo]) {
        self.recorder = recorder
        self.sources = sources
        super.init()
        window.title = String(localized: "Statistics")
        window.closesOnEscape = true
        window.isReleasedWhenClosed = false
        window.backgroundColor = Tokens.surface

        let periods = [String(localized: "Today"), String(localized: "7 Days"), String(localized: "30 Days")]
        segments.segmentCount = periods.count
        for (index, title) in periods.enumerated() { segments.setLabel(title, forSegment: index) }
        segments.trackingMode = .selectOne
        segments.selectedSegment = 0
        segments.target = self
        segments.action = #selector(reload)

        let headline = NSStackView(views: [switches, NSView(), switchesChange])
        headline.alignment = .firstBaseline
        let separator = NSBox()
        separator.boxType = .separator
        let rows = [Self.pair(distance, speed), Self.pair(clicks, scroll)]
        let tiles = NSStackView(views: rows)
        tiles.orientation = .vertical
        tiles.spacing = 8  // space-2
        for row in rows { row.widthAnchor.constraint(equalTo: tiles.widthAnchor).isActive = true }

        let pointerTitle = label(String(localized: "Pointer"), size: 15, weight: .semibold, color: Tokens.ink)
        let typingTitle = label(String(localized: "Typing"), size: 15, weight: .semibold, color: Tokens.ink)
        let typingSeparator = NSBox()
        typingSeparator.boxType = .separator
        let typingTiles = Self.pair(keystrokes, perMinute)
        typingDetail.orientation = .vertical
        typingDetail.alignment = .leading
        typingDetail.spacing = 6
        typingOn.orientation = .vertical
        typingOn.alignment = .leading
        typingOn.spacing = 6
        typingOn.setViews([typingTiles, typingBars, typingAxis, typingDetail], in: .leading)
        typingOn.setCustomSpacing(10, after: typingTiles)
        typingOn.setCustomSpacing(12, after: typingAxis)
        for view in [typingTiles, typingBars, typingAxis, typingDetail] { view.widthAnchor.constraint(equalTo: typingOn.widthAnchor).isActive = true }
        typingBars.setAccessibilityLabel(String(localized: "Keystrokes per hour"))
        let column = NSStackView(views: [
            segments,
            label(String(localized: "Input Source"), size: 15, weight: .semibold, color: Tokens.ink),  // title
            switchesTitle,
            headline, bars, axis, separator, typingTitle, typingOn, promo, typingSeparator, pointerTitle, tiles,
        ])
        column.setCustomSpacing(12, after: typingOn)
        column.setCustomSpacing(12, after: promo)
        column.setCustomSpacing(12, after: typingSeparator)
        column.setCustomSpacing(10, after: typingTitle)
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 6
        column.setCustomSpacing(16, after: segments)
        column.setCustomSpacing(12, after: axis)
        column.setCustomSpacing(12, after: separator)
        column.setCustomSpacing(10, after: pointerTitle)
        column.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)  // space-3
        column.translatesAutoresizingMaskIntoConstraints = false
        column.widthAnchor.constraint(equalToConstant: Self.width).isActive = true
        segments.centerXAnchor.constraint(equalTo: column.centerXAnchor).isActive = true
        for view in [headline, bars, axis, separator, tiles, typingOn, promo, typingSeparator] {
            view.widthAnchor.constraint(equalTo: column.widthAnchor, constant: -32).isActive = true
        }
        bars.setAccessibilityLabel(String(localized: "Switches per hour"))
        // 화면보다 길면(작은 화면에서 타이핑 구역까지 보일 때) 스크롤한다.
        let document = FlippedView()
        document.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(column)
        scrollView.documentView = document
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        NSLayoutConstraint.activate([
            document.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            document.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            document.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            column.topAnchor.constraint(equalTo: document.topAnchor),
            column.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            column.bottomAnchor.constraint(equalTo: document.bottomAnchor),
        ])
        window.contentView = scrollView
        self.column = column

        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
            self?.timer?.invalidate()
            self?.timer = nil
        }
    }

    private static func pair(_ left: NSView, _ right: NSView) -> NSStackView {
        let row = NSStackView(views: [left, right])
        row.distribution = .fillEqually
        row.spacing = 8  // space-2
        return row
    }

    func show() {
        reload()
        if !window.isVisible { window.center() }
        NSApp.activateForWindow()
        window.makeKeyAndOrderFront(nil)
        // 열려 있는 동안 2초마다 새로 읽는다. 다른 창에 가려 안 보이면 건너뛴다.
        guard timer == nil else { return }
        let timer = Timer(timeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            guard let self, self.window.occlusionState.contains(.visible) else { return }
            self.reload()
        }
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    @objc private func reload() {
        let period = StatsPeriod(rawValue: segments.selectedSegment) ?? .today
        let now = Date()
        let log = recorder.snapshot
        let summary = StatsSummary(log: log, period: period, now: now, calendar: .current)
        let (current, previous) = (summary.current, summary.previous)
        let locale = Locale.current
        func change(_ value: Double, _ before: Double) -> String { StatsChange.between(value, before)?.text(period) ?? "" }

        switches.show(count: current.switches)
        switchesChange.stringValue = change(current.switches, previous.switches)
        bars.values = summary.bars
        bars.setAccessibilityLabel(period == .today ? String(localized: "Switches per hour") : String(localized: "Switches per day"))
        axis.show(period, now: now)

        distance.value.show(StatsFormat.distance(millimeters: current.distance, locale: locale))
        distance.detail.stringValue = change(current.distance, previous.distance)
        speed.value.show(StatsFormat.speed(millimetersPerSecond: current.averageSpeed, locale: locale))
        speed.detail.stringValue = change(current.averageSpeed, previous.averageSpeed)
        clicks.value.show(count: current.clicks)
        let count = { StatsFormat.count($0, locale: locale) }
        clicks.detail.stringValue = String(localized: "Left \(count(current.leftClicks)) · Right \(count(current.rightClicks)) · Double \(count(current.doubleClicks))")
        scroll.value.show(StatsFormat.distance(millimeters: current.scroll, locale: locale))
        scroll.detail.stringValue = change(current.scroll, previous.scroll)
        let sources = sources()
        switchesTitle.stringValue = TypingFormat.switchesTitle(sourceCount: sources.count)

        let state = recorder.typingState
        typingOn.isHidden = state != .on
        promo.isHidden = state == .on
        promo.show(state)
        if state == .on { reloadTyping(log: log, summary: summary, period: period, now: now, sources: sources) }
        // 증감을 숨겨도 칸 높이가 바뀌지 않게 빈 줄을 남긴다.
        for tile in [distance, speed, scroll, keystrokes, perMinute] where tile.detail.stringValue.isEmpty { tile.detail.stringValue = " " }
        fitWindow()
    }

    // 타이핑 구역·줄 수에 따라 내용 높이가 바뀌므로 창 높이를 맞춘다. 위 모서리는 그 자리에 둔다.
    private func fitWindow() {
        column.layoutSubtreeIfNeeded()
        let titleBar = window.frame.height - window.contentLayoutRect.height
        let limit = ((window.screen ?? NSScreen.main)?.visibleFrame.height ?? .infinity) - titleBar
        let height = min(column.fittingSize.height, limit)
        guard abs(window.contentLayoutRect.height - height) > 0.5 else { return }
        var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: NSSize(width: Self.width, height: height)))
        frame.origin = NSPoint(x: window.frame.minX, y: window.frame.maxY - frame.height)
        // 늘어나 화면 아래로 나가면 화면 안으로 올린다.
        if let visible = (window.screen ?? NSScreen.main)?.visibleFrame, frame.minY < visible.minY { frame.origin.y = visible.minY }
        window.setFrame(frame, display: true)
    }

    private func reloadTyping(log: StatsLog, summary: StatsSummary, period: StatsPeriod, now: Date, sources: [String: InputSourceInfo]) {
        let (current, previous) = (summary.current, summary.previous)
        func change(_ value: Double, _ before: Double) -> String { StatsChange.between(value, before)?.text(period) ?? "" }
        let speed = TypingFormat.perMinute(keystrokes: current.keystrokes, seconds: current.typingTime)
        keystrokes.value.show(count: current.keystrokes)
        keystrokes.detail.stringValue = change(current.keystrokes, previous.keystrokes)
        perMinute.value.show(count: speed)
        perMinute.detail.stringValue = change(speed, TypingFormat.perMinute(keystrokes: previous.keystrokes, seconds: previous.typingTime))
        typingBars.values = summary.typingBars
        typingBars.setAccessibilityLabel(period == .today ? String(localized: "Keystrokes per hour") : String(localized: "Keystrokes per day"))
        typingAxis.show(period, now: now)

        var views: [NSView] = []
        let shares = StatsShare.rows(current.sourceKeystrokes, limit: 3)
        // 앱별 막대 안 색도 같은 순위를 쓴다.
        let ranks = Dictionary(uniqueKeysWithValues: shares.enumerated().compactMap { index, share in share.name.map { ($0, index) } })
        if !shares.isEmpty {
            views.append(label(String(localized: "By Input Source"), size: 11, weight: .semibold))
            let bar = StackBarView(height: 10, radius: 5)
            bar.segments = shares.enumerated().map { ($1.value, sourceColor($1.name == nil ? nil : $0)) }
            views.append(bar)
            for (rank, share) in shares.enumerated() {
                let speed = share.name.map { TypingFormat.perMinute(keystrokes: current.sourceKeystrokes[$0] ?? 0, seconds: current.sourceTypingTime[$0] ?? 0) }
                views.append(sourceRow(share, rank: share.name == nil ? 3 : rank, perMinute: speed,
                                       sources: sources, swatch: 10, count: true))
            }
        }
        let apps = log.apps(days: period.days, now: now, calendar: .current)
        let appShares = StatsShare.rows(apps.mapValues { $0.values.reduce(0, +) }, limit: 5)
        let appsHeader = label(String(localized: "By App"), size: 11, weight: .semibold)
        if !appShares.isEmpty {
            views.append(appsHeader)
            let top = appShares.first?.value ?? 1
            for share in appShares {
                guard let bundle = share.name else {
                    views.append(label(String(localized: "\(share.otherCount) other apps"), size: 11))
                    continue
                }
                let name = label(Self.appName(bundle), size: 13, color: Tokens.ink)
                name.lineBreakMode = .byTruncatingTail
                name.widthAnchor.constraint(equalToConstant: 64).isActive = true
                name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                let bar = StackBarView(height: 8, radius: 2)
                bar.length = share.value / top
                bar.segments = (apps[bundle] ?? [:]).sorted { (ranks[$0.key] ?? 3) < (ranks[$1.key] ?? 3) }.map { ($0.value, sourceColor(ranks[$0.key])) }
                let count = label(countText(share.value), size: 13)
                count.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
                count.alignment = .right
                count.widthAnchor.constraint(equalToConstant: 76).isActive = true
                views.append(hstack([name, bar, count], spacing: 8, alignment: .centerY))
            }
        }
        typingDetail.setViews(views, in: .leading)
        for view in views { view.widthAnchor.constraint(equalTo: typingDetail.widthAnchor).isActive = true }
        // '앱별'은 입력소스별 줄과 다른 묶음이라 위를 띄운다.
        if let index = views.firstIndex(of: appsHeader), index > 0 { typingDetail.setCustomSpacing(12, after: views[index - 1]) }
    }

    // 번들 ID로 앱 이름을 읽는다. 지운 앱이면 번들 ID를 그대로 쓴다.
    private static func appName(_ bundle: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) else { return bundle }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }
}
