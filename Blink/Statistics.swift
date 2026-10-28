import Foundation

// 입력 통계의 판단·계산. AppKit 없이 값만 다룬다. 이벤트를 받아 세는 쪽과 화면은 StatisticsUI.swift에 있다.

// 한 시간(또는 하루) 동안 센 사용량. 시간 칸 일부만 더할 때 비율을 곱하므로 횟수도 Double이다.
struct StatsCounts: Codable, Equatable {
    var switches = 0.0
    var distance = 0.0  // 포인터 이동, mm
    var movingTime = 0.0  // 포인터가 움직인 시간, 초
    var topSpeed = 0.0  // mm/s. 1.5.0 최고 기록용으로 저장만 한다
    var leftClicks = 0.0
    var rightClicks = 0.0
    var doubleClicks = 0.0
    var scroll = 0.0  // mm

    var clicks: Double { leftClicks + rightClicks + doubleClicks }
    var averageSpeed: Double { movingTime > 0 ? distance / movingTime : 0 }

    // fraction: 시간 칸의 일부만 더할 때의 비율. 최고 속도는 나누지 않는다.
    mutating func add(_ other: StatsCounts, fraction: Double = 1) {
        switches += other.switches * fraction
        distance += other.distance * fraction
        movingTime += other.movingTime * fraction
        topSpeed = max(topSpeed, other.topSpeed)
        leftClicks += other.leftClicks * fraction
        rightClicks += other.rightClicks * fraction
        doubleClicks += other.doubleClicks * fraction
        scroll += other.scroll * fraction
    }

    // 누름 한 번. 두 번째 누름부터(clickCount 2 이상)는 더블로 센다. 가운데 버튼 등은 세지 않는다.
    static func click(left: Bool, clickCount: Int) -> StatsCounts {
        var counts = StatsCounts()
        if !left { counts.rightClicks = 1 } else if clickCount >= 2 { counts.doubleClicks = 1 } else { counts.leftClicks = 1 }
        return counts
    }
}

// 한 시간마다 합계 칸 하나(90일), 하루 합계(계속). 키 순서·내용은 없다.
struct StatsLog: Codable, Equatable {
    static let hourRetention: TimeInterval = 90 * 24 * 3600

    // 키: 그 시간의 시작(1970년부터 초). 30분 단위 시간대도 있어 시간 번호가 아니라 시작 시각을 쓴다.
    private(set) var hours: [Int: StatsCounts] = [:]
    // 키: "2026-10-28". 지금은 보여 주지 않고, 시간 칸이 지워진 뒤의 '전체' 기간용으로 남긴다.
    private(set) var days: [String: StatsCounts] = [:]

    mutating func add(_ counts: StatsCounts, at date: Date, calendar: Calendar) {
        guard let hour = calendar.dateInterval(of: .hour, for: date)?.start else { return }
        hours[Int(hour.timeIntervalSince1970), default: StatsCounts()].add(counts)
        let day = calendar.dateComponents([.year, .month, .day], from: date)
        days[String(format: "%04d-%02d-%02d", day.year ?? 0, day.month ?? 0, day.day ?? 0), default: StatsCounts()].add(counts)
    }

    mutating func prune(now: Date) {
        let oldest = now.timeIntervalSince1970 - Self.hourRetention
        hours = hours.filter { Double($0.key) >= oldest }
    }

    // [from, to) 사이의 합계. 구간이 시간 칸 중간에서 끝나면 그 칸은 겹친 비율만큼 더한다.
    // 지금 진행 중인 칸은 지금까지만 센 것이라 칸 길이를 지금까지로 본다.
    func total(from: Date, to: Date, now: Date) -> StatsCounts {
        var sum = StatsCounts()
        for (key, counts) in hours {
            let start = Double(key)
            let end = min(start + 3600, now.timeIntervalSince1970)
            let overlap = min(end, to.timeIntervalSince1970) - max(start, from.timeIntervalSince1970)
            guard overlap > 0, end > start else { continue }
            sum.add(counts, fraction: min(1, overlap / (end - start)))
        }
        return sum
    }
}

// 통계 창의 기간. 증감은 같은 길이만큼 앞 기간과, 같은 시각까지 비교한다.
enum StatsPeriod: Int, CaseIterable {
    case today, week, month

    var days: Int {
        switch self {
        case .today: 1
        case .week: 7
        case .month: 30
        }
    }

    // current: 오늘 포함 최근 기간의 시작부터 지금까지. previous: 그 앞 같은 길이, 끝은 지금에서 기간만큼 앞.
    func ranges(now: Date, calendar: Calendar) -> (current: DateInterval, previous: DateInterval) {
        let start = calendar.date(byAdding: .day, value: 1 - days, to: calendar.startOfDay(for: now))!
        let previousStart = calendar.date(byAdding: .day, value: -days, to: start)!
        let previousEnd = calendar.date(byAdding: .day, value: -days, to: now)!
        return (DateInterval(start: start, end: now), DateInterval(start: previousStart, end: max(previousStart, previousEnd)))
    }

    // 막대 칸: 오늘은 오늘의 시간(서머타임이면 23·25개), 7일·30일은 날.
    func slots(now: Date, calendar: Calendar) -> [DateInterval] {
        let start = calendar.date(byAdding: .day, value: 1 - days, to: calendar.startOfDay(for: now))!
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
        let unit: Calendar.Component = self == .today ? .hour : .day
        var slots: [DateInterval] = []
        var cursor = start
        while cursor < end, let next = calendar.date(byAdding: unit, value: 1, to: cursor) {
            slots.append(DateInterval(start: cursor, end: next))
            cursor = next
        }
        return slots
    }

    // 막대 아래 눈금. 오늘은 0 6 12 18 24, 7일은 요일, 30일은 첫날 날짜. 7일·30일의 마지막은 '오늘'.
    func axisLabels(now: Date, calendar: Calendar, locale: Locale) -> [String] {
        let style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
        let slots = slots(now: now, calendar: calendar)
        switch self {
        case .today: return ["0", "6", "12", "18", "24"]
        case .week: return slots.dropLast().map { $0.start.formatted(style.weekday(.abbreviated)) } + [String(localized: "Today")]
        case .month: return [slots[0].start.formatted(style.month(.defaultDigits).day()), String(localized: "Today")]
        }
    }
}

// 기간 하나를 보여 주는 데 필요한 값.
struct StatsSummary: Equatable {
    var current: StatsCounts
    var previous: StatsCounts
    var bars: [Double]  // 칸마다 전환 횟수

    init(log: StatsLog, period: StatsPeriod, now: Date, calendar: Calendar) {
        let ranges = period.ranges(now: now, calendar: calendar)
        current = log.total(from: ranges.current.start, to: ranges.current.end, now: now)
        previous = log.total(from: ranges.previous.start, to: ranges.previous.end, now: now)
        bars = period.slots(now: now, calendar: calendar).map { log.total(from: $0.start, to: $0.end, now: now).switches }
    }
}

// 앞 기간 대비 증감. 색 없이 ▲·▼로만 보여 준다.
enum StatsChange: Equatable {
    case same, up(Int), down(Int)

    // 앞 기간이 0이면 nil(숨김). 1% 미만이면 같음.
    static func between(_ current: Double, _ previous: Double) -> StatsChange? {
        guard previous > 0 else { return nil }
        let percent = (current - previous) / previous * 100
        if abs(percent) < 1 { return .same }
        return percent > 0 ? .up(Int(percent.rounded())) : .down(Int((-percent).rounded()))
    }

    func text(_ period: StatsPeriod) -> String {
        let arrow = switch self {
        case .same: ""
        case .up(let percent): "▲\(percent)%"
        case .down(let percent): "▼\(percent)%"
        }
        switch (self, period) {
        case (.same, .today): return String(localized: "Same as yesterday")
        case (.same, .week): return String(localized: "Same as previous 7 days")
        case (.same, .month): return String(localized: "Same as previous 30 days")
        case (_, .today): return String(localized: "\(arrow) vs yesterday")
        case (_, .week): return String(localized: "\(arrow) vs previous 7 days")
        case (_, .month): return String(localized: "\(arrow) vs previous 30 days")
        }
    }
}

enum StatsBars {
    // 가장 많은 칸을 꽉 찬 높이로 잡은 비율. 0이 아닌 칸은 보이도록 최소 높이를 준다.
    static func heights(_ values: [Double], height: Double, minimum: Double = 2) -> [Double] {
        guard let top = values.max(), top > 0 else { return values.map { _ in 0 } }
        return values.map { $0 > 0 ? max(minimum, height * $0 / top) : 0 }
    }
}

// 포인터 이벤트 사이의 거리·움직인 시간·최고 속도를 센다. 시각은 이벤트의 timestamp(초)를 쓴다.
struct PointerMeter {
    // 이벤트 사이가 이보다 길면 멈췄다가 다시 움직인 것으로 보고 움직인 시간에 넣지 않는다.
    static let idleGap: TimeInterval = 0.5
    // 최고 속도는 이 시간 이상 모아서 잰다(이벤트 하나 사이의 속도는 들쭉날쭉하다).
    static let speedWindow: TimeInterval = 0.25

    private var last: (point: CGPoint, time: TimeInterval)?
    private var window = (distance: 0.0, time: 0.0)

    mutating func move(to point: CGPoint, at time: TimeInterval, millimetersPerPoint: Double) -> StatsCounts {
        defer { last = (point, time) }
        guard let last else { return StatsCounts() }
        var counts = StatsCounts()
        counts.distance = hypot(point.x - last.point.x, point.y - last.point.y) * millimetersPerPoint
        let gap = time - last.time
        guard gap > 0, gap <= Self.idleGap else {
            window = (0, 0)
            return counts
        }
        counts.movingTime = gap
        window.distance += counts.distance
        window.time += gap
        if window.time >= Self.speedWindow {
            counts.topSpeed = window.distance / window.time
            window = (0, 0)
        }
        return counts
    }

    // 화면의 실제 폭(mm)을 포인트 폭으로 나눈다. 크기를 알려 주지 않는 화면(0)은 110pt/inch로 본다.
    static func millimetersPerPoint(physicalWidth: Double, pointWidth: Double) -> Double {
        guard physicalWidth > 0, pointWidth > 0 else { return 25.4 / 110 }
        return physicalWidth / pointWidth
    }

    // 스크롤 길이(pt). 트랙패드·매직 마우스는 포인트, 휠 마우스는 줄 단위라 한 줄을 10pt로 본다.
    static func scrollPoints(dx: Double, dy: Double, precise: Bool) -> Double {
        hypot(dx, dy) * (precise ? 1 : 10)  // ponytail: 줄 높이는 앱마다 다르다. 휠 사용자가 많으면 실측값으로 바꾼다
    }
}

// 통계 숫자 표기. 단위는 지역 설정을 따른다(미국은 마일·피트·인치).
enum StatsFormat {
    static func count(_ value: Double, locale: Locale) -> String {
        value.rounded().formatted(.number.precision(.fractionLength(0)).locale(locale))
    }

    // 유효숫자 세 자리: 1.33 km, 113 m, 12.4 cm. 단위는 크기에 맞춰 고른다(naturalScale은 0.124 m처럼 고른다).
    static func distance(millimeters: Double, locale: Locale) -> String {
        let length = Measurement(value: millimeters, unit: UnitLength.millimeters)
        let units: [(UnitLength, below: Double)] = locale.measurementSystem == .us
            ? [(.inches, 12 * 25.4), (.feet, 1_609_344), (.miles, .infinity)]
            : [(.millimeters, 10), (.centimeters, 1000), (.meters, 1_000_000), (.kilometers, .infinity)]
        // 세 자리로 반올림한 값으로 단위를 골라 9.996 mm가 "10 mm"가 아니라 "1 cm"가 되게 한다.
        let rounded = Double(String(format: "%.3g", millimeters)) ?? millimeters
        let unit = units.first { rounded < $0.below }!.0
        let formatter = MeasurementFormatter()
        formatter.locale = locale
        formatter.unitOptions = .providedUnit
        formatter.numberFormatter.locale = locale
        formatter.numberFormatter.usesSignificantDigits = true
        formatter.numberFormatter.maximumSignificantDigits = 3
        return formatter.string(from: length.converted(to: unit))
    }

    static func speed(millimetersPerSecond: Double, locale: Locale) -> String {
        String(localized: "\(distance(millimeters: millimetersPerSecond, locale: locale))/s")
    }
}
