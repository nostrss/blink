// 포인터 배지가 언제 보이는지(배지 보기). 항상·움직일 때는 포인터를 따라가고, 클릭할 때는 클릭한 자리에 머문다.
enum BadgeMode: String, CaseIterable {
    case always, moving, click

    // 배지가 받는 일. clicked의 count는 연속 클릭의 몇 번째 누름인지(NSEvent.clickCount).
    enum Event: Equatable {
        case moved, clicked(count: Int), switched
    }

    // 저장된 값. 없거나 읽을 수 없으면 클릭할 때(1.3.0까지의 '포인터가 멈추면 숨기기'는 옮기지 않는다).
    init(saved: String?) {
        self = saved.flatMap(Self.init(rawValue:)) ?? .click
    }

    // 포인터를 따라가면 마우스 이동을, 아니면 클릭만 감시한다.
    var followsPointer: Bool { self != .click }

    var hidesAfterDuration: Bool { self != .always }

    // 이 일에 배지를 포인터 자리로 옮겨 보일지. 더블·트리플클릭의 두 번째 이후 누름은 무시한다.
    func reveals(on event: Event) -> Bool {
        switch event {
        case .moved: followsPointer
        case .clicked(let count): !followsPointer && count < 2
        case .switched: true
        }
    }
}
