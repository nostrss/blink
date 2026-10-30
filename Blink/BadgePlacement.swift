import CoreGraphics

// 포인터 배지가 포인터의 어느 쪽에 붙는지(배지 위치). 포인터 둘레 8방위이고, 가운데는 포인터를 가려서 없다.
enum BadgePlacement: String, CaseIterable {
    case topLeft, top, topRight, left, right, bottomLeft, bottom, bottomRight

    static let standard = BadgePlacement.bottomRight
    // 포인터 영역: 표준 화살표 포인터가 흰 외곽선까지 차지하는 자리. 끝점 기준이고 y는 아래로 증가한다.
    // 외곽선이 끝점보다 2pt쯤 위·왼쪽으로 나와 있어, 끝점에서 시작하면 위·왼쪽 배지만 포인터에 붙어 보인다.
    // 배지는 그 바깥에 space-1만큼 띄운다.
    static let pointerArea = CGRect(x: -2, y: -2, width: 13, height: 19)
    static let gap: CGFloat = 4

    // 저장된 값. 없거나 읽을 수 없으면 기본값(오른쪽 아래).
    init(saved: String?) {
        self = saved.flatMap(Self.init(rawValue:)) ?? .standard
    }

    // 포인터가 메뉴바·Dock 위에 있는지. visibleFrame은 포인터가 있는 화면에서 메뉴바·Dock을 뺀 영역이다.
    // 자동으로 가리는 메뉴바·Dock은 visibleFrame이 빼지 않아 알아채지 못한다.
    static func isOverSystemBar(pointer: CGPoint, visibleFrame: CGRect) -> Bool {
        !visibleFrame.contains(pointer)
    }

    // 가로 -1 왼쪽, 0 가운데, 1 오른쪽.
    var column: Int {
        switch self {
        case .topLeft, .left, .bottomLeft: -1
        case .top, .bottom: 0
        case .topRight, .right, .bottomRight: 1
        }
    }

    // 세로 -1 위, 0 가운데, 1 아래.
    var row: Int {
        switch self {
        case .topLeft, .top, .topRight: -1
        case .left, .right: 0
        case .bottomLeft, .bottom, .bottomRight: 1
        }
    }

    // AppKit 좌표(y가 위로 증가)에서 배지의 왼쪽 아래 모서리. pointer는 포인터 끝점.
    // frame을 넘치면 넘친 축만 반대쪽으로 뒤집고, 그래도 넘치면 frame 안으로 밀어 넣는다.
    func origin(size: CGSize, pointer: CGPoint, in frame: CGRect) -> CGPoint {
        let area = Self.pointerArea, gap = Self.gap
        func x(_ column: Int) -> CGFloat {
            switch column {
            case -1: pointer.x + area.minX - gap - size.width
            case 1: pointer.x + area.maxX + gap
            default: pointer.x + area.midX - size.width / 2
            }
        }
        func y(_ row: Int) -> CGFloat {
            switch row {
            case -1: pointer.y - area.minY + gap
            case 1: pointer.y - area.maxY - gap - size.height
            default: pointer.y - area.midY - size.height / 2
            }
        }
        var originX = x(column), originY = y(row)
        if column != 0, originX < frame.minX || originX + size.width > frame.maxX { originX = x(-column) }
        if row != 0, originY < frame.minY || originY + size.height > frame.maxY { originY = y(-row) }
        originX = min(max(originX, frame.minX), frame.maxX - size.width)
        originY = min(max(originY, frame.minY), frame.maxY - size.height)
        return CGPoint(x: originX.rounded(), y: originY.rounded())
    }
}
