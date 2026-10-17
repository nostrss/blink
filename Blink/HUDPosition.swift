import CoreGraphics

// HUD가 뜰 자리(표시 위치). 화면의 visibleFrame에서 여백만큼 들인 영역 안에서 HUD가 움직일 수 있는 범위에 대한 비율이다.
// x는 0이 왼쪽, y는 0이 위. 9방위 프리셋은 x, y가 각각 0, 0.5, 1인 조합이다.
struct HUDPosition: Equatable {
    static let center = HUDPosition(x: 0.5, y: 0.5)
    // 위에서 아래로, 왼쪽에서 오른쪽으로.
    static let presets = [0.0, 0.5, 1.0].flatMap { y in [0.0, 0.5, 1.0].map { x in HUDPosition(x: x, y: y) } }

    let x: Double
    let y: Double

    // 0–1 밖은 가장자리로, 숫자가 아니면 가운데로 고친다.
    init(x: Double, y: Double) {
        self.x = x.isFinite ? min(max(x, 0), 1) : 0.5
        self.y = y.isFinite ? min(max(y, 0), 1) : 0.5
    }

    // 프리셋이면 presets 안의 번호, 직접 지정이면 nil.
    var presetIndex: Int? { Self.presets.firstIndex(of: self) }

    // AppKit 좌표(y가 위로 증가)에서 HUD의 왼쪽 아래 모서리. HUD가 영역보다 크면 그 축은 가운데에 둔다.
    func origin(size: CGSize, in frame: CGRect, margin: CGFloat) -> CGPoint {
        let area = frame.insetBy(dx: margin, dy: margin)
        let freeX = area.width - size.width, freeY = area.height - size.height
        let x = area.minX + freeX * (freeX < 0 ? 0.5 : self.x)
        let y = area.maxY - size.height - freeY * (freeY < 0 ? 0.5 : self.y)
        return CGPoint(x: x.rounded(), y: y.rounded())
    }

    // origin의 반대. 끌어 놓은 HUD의 왼쪽 아래 모서리를 위치로 바꾸고, 프리셋 자리에서 snap 이내면 그 프리셋에 붙인다.
    static func dragged(to origin: CGPoint, size: CGSize, in frame: CGRect, margin: CGFloat, snap: CGFloat) -> HUDPosition {
        let area = frame.insetBy(dx: margin, dy: margin)
        let freeX = area.width - size.width, freeY = area.height - size.height
        let position = HUDPosition(x: freeX > 0 ? (origin.x - area.minX) / freeX : 0.5,
                                   y: freeY > 0 ? (area.maxY - size.height - origin.y) / freeY : 0.5)
        let at = position.origin(size: size, in: frame, margin: margin)
        return presets.first {
            let p = $0.origin(size: size, in: frame, margin: margin)
            return hypot(p.x - at.x, p.y - at.y) < snap
        } ?? position
    }
}
