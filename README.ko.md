# Blink

[English](README.md)

Blink는 macOS 메뉴바 앱입니다. 키보드 입력소스가 바뀌는 순간 "ABC → 두벌식"처럼 무엇에서 무엇으로 바뀌었는지 화면에 눈 깜빡할 만큼 띄웁니다. 문장을 다 쓰고 나서야 한/영이 잘못된 걸 알아채는 일이 없어집니다.

![Blink HUD](docs/appstore/1.4.0/ko/1.4.0-ko-1.png)

[Mac App Store에서 받기](https://apps.apple.com/kr/app/blink-input-language-alert/id6823983837)

## 기능

- 마우스가 있는 화면에, 전체화면 앱 위와 모든 Space에서 HUD를 띄웁니다. 클릭은 그대로 통과합니다.
- 입력소스 이름 그대로, 또는 "EN"·"한" 같은 약자로. 변경 전을 숨길 수도 있습니다.
- 9군데 위치 중 고르거나 끌어서 원하는 자리에, 표시 시간 0.5–5초.
- 테마: 기본(macOS Tahoe 26에서는 Liquid Glass), 클래식, 고대비, Dracula, Gruvbox, Rosé Pine, 나만의 색.
- 포인터 배지: 포인터 옆에 지금 입력소스를, 항상·움직일 때·클릭한 자리에.
- Caps Lock HUD: Caps Lock을 누르면 "⇪ 켜짐"·"⇪ 꺼짐".
- 통계: 한/영 전환과 포인터 사용, 켜면 입력소스별·앱별 타이핑 통계까지.
- 손쉬운 사용의 투명도 줄이기·동작 줄이기를 따릅니다. 로그인할 때 자동 실행(원할 때만).
- 영어, 한국어, 일본어, 중국어(간체·번체), 러시아어, 독일어, 프랑스어, 스페인어, 포르투갈어(브라질).

버전별로 바뀐 점은 [변경 이력](CHANGELOG.ko.md)에 있습니다.

## 개인정보

Blink는 App Sandbox에서 실행되고, 인터넷에 접속하지 않으며, 아무것도 수집하지 않습니다. 통계는 이 Mac 안에만 남고 언제든 끄거나 지울 수 있습니다. 타이핑 통계는 기본으로 꺼져 있고, 켜면 입력 모니터링 권한을 묻습니다. 누른 키의 개수만 셀 뿐 어떤 키를 눌렀는지, 무엇을 입력했는지는 기록하지 않습니다.

[개인정보 처리방침](https://nostrss.github.io/blink-site/privacy)

## 요구 사항

macOS 13 Ventura 이상.

## 소스에서 빌드하기

Xcode가 필요합니다. 외부 라이브러리는 없습니다.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Blink.xcodeproj -scheme Blink -configuration Debug -derivedDataPath build test
```

Debug 빌드는 **Blink Dev**(`build/Build/Products/Debug/Blink Dev.app`, 번들 ID `com.jintaek.blink.dev`, 메뉴바 아이콘에 점)입니다. App Store판과 설정·통계·권한을 따로 씁니다. 띄우기 전에 App Store판 Blink를 끄세요. 둘 다 켜 두면 HUD가 두 번 뜹니다.

## 지원

질문, 버그 제보, 의견: [blinkapp.support@gmail.com](mailto:blinkapp.support@gmail.com)
