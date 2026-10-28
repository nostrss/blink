import AppKit

// 입력 통계를 세고(StatsRecorder) 보여 주는(메뉴 카드, 통계 창) AppKit 층. 계산은 Statistics.swift에 있다.

// 전환·포인터 이벤트를 받아 StatsLog에 더하고 파일에 저장한다. 포인터 이벤트는 손쉬운 사용 권한 없이 받을 수 있다.
final class StatsRecorder {
    static let enabledKey = "collectStatistics"
    private static let saveInterval: TimeInterval = 900

    private var log = StatsLog()
    // 포인터 이벤트는 1초에 수백 번 오므로 지금 시간 칸의 합계만 메모리에 더하고, 칸이 바뀌거나 읽을 때 기록에 넣는다.
    private var pending = StatsCounts()
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
    }

    func countSwitch() {
        guard isEnabled else { return }
        add(StatsCounts(switches: 1))
    }

    func clear() {
        log = StatsLog()
        pending = StatsCounts()
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
        log.add(pending, at: pendingHourEnd.addingTimeInterval(-1), calendar: .current)
        pending = StatsCounts()
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

// 전환 막대. 높이 48pt, accent 막대, line 바닥선. VoiceOver는 이미지 하나로 읽는다.
final class StatsBarsView: NSView {
    static let height: CGFloat = 48
    private static let gap: CGFloat = 2

    var values: [Double] = [] { didSet { needsDisplay = true } }

    override init(frame: NSRect) {
        super.init(frame: frame)
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: Self.height + 1) }

    override func draw(_ dirtyRect: NSRect) {
        Tokens.line.setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: 1).fill()
        guard !values.isEmpty else { return }
        let width = (bounds.width - Self.gap * CGFloat(values.count - 1)) / CGFloat(values.count)
        Tokens.accent.setFill()
        for (index, height) in StatsBars.heights(values, height: Self.height).enumerated() where height > 0 {
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

// 메뉴 맨 위 카드: 오늘 전환 횟수, 어제 대비, 오늘 시간별 막대. 누를 수 없다(NSMenuItem.view).
final class StatsCardView: NSView {
    static let width: CGFloat = 260
    // 메뉴 항목 글자와 같은 줄에서 시작한다.
    static let inset: CGFloat = 14

    private let total = BigNumberView()
    private let change = label(size: 13)  // body
    private let bars = StatsBarsView()
    private let axis = StatsAxisView()
    private let stack = NSStackView()

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: Self.width, height: 0))
        let title = label(String(localized: "Input Source Switches Today"), size: 11, weight: .semibold)  // caption, 굵게
        stack.setViews([title, total, change, bars, axis], in: .leading)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 8, left: Self.inset, bottom: 10, right: Self.inset)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.widthAnchor.constraint(equalToConstant: Self.width),
            bars.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -2 * Self.inset),
            axis.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -2 * Self.inset),
        ])
        bars.setAccessibilityLabel(String(localized: "Switches per hour"))
    }

    required init?(coder: NSCoder) { fatalError() }

    func reload(_ log: StatsLog) {
        let now = Date()
        let summary = StatsSummary(log: log, period: .today, now: now, calendar: .current)
        total.show(count: summary.current.switches)
        let delta = StatsChange.between(summary.current.switches, summary.previous.switches)
        change.stringValue = delta?.text(.today) ?? ""
        change.isHidden = delta == nil
        bars.values = summary.bars
        axis.show(.today, now: now)
        setFrameSize(NSSize(width: Self.width, height: stack.fittingSize.height))
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
    private static let refreshInterval: TimeInterval = 2

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
    private var timer: Timer?

    init(recorder: StatsRecorder) {
        self.recorder = recorder
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
        let column = NSStackView(views: [
            segments,
            label(String(localized: "Input Source"), size: 15, weight: .semibold, color: Tokens.ink),  // title
            label(String(localized: "Input Source Switches"), size: 11),  // caption
            headline, bars, axis, separator, pointerTitle, tiles,
        ])
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
        for view in [headline, bars, axis, separator, tiles] {
            view.widthAnchor.constraint(equalTo: column.widthAnchor, constant: -32).isActive = true
        }
        bars.setAccessibilityLabel(String(localized: "Switches per hour"))
        window.contentView = column

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
        let summary = StatsSummary(log: recorder.snapshot, period: period, now: now, calendar: .current)
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
        // 증감을 숨겨도 칸 높이가 바뀌지 않게 빈 줄을 남긴다.
        for tile in [distance, speed, scroll] where tile.detail.stringValue.isEmpty { tile.detail.stringValue = " " }
    }
}
