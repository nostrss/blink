# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 프로젝트

Blink: macOS 메뉴바 앱. 한/영 입력소스가 바뀌면 화면 중앙에 "변경 전 → 변경 후"를 1초 띄운다. Swift + AppKit, 외부 라이브러리 없음. 사용자와는 한국어로 소통한다.

macOS 전용 타깃(최소 13.0, `LSUIElement`), 진입점은 `Blink/AppDelegate.swift`의 `static func main()`이다 (MainMenu nib 없음).

## 빌드

`xcode-select`가 Command Line Tools를 가리키고 있어 `xcodebuild`를 그냥 실행하면 실패한다. `DEVELOPER_DIR`를 지정한다.

빌드는 항상 `test` 액션으로 한다. 앱을 빌드하고 단위 테스트(`BlinkTests`)까지 돌리며, 테스트가 하나라도 실패하면 빌드가 실패한 것으로 보고 다음 단계(실행, 화면 확인, 커밋)로 넘어가지 않는다:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Blink.xcodeproj -scheme Blink -configuration Debug -derivedDataPath build test
```

결과물: `build/Build/Products/Debug/Blink.app` (`build/`는 gitignore됨). 출력 끝의 `TEST SUCCEEDED`만 믿지 말고 `Test case ... passed` 줄로 테스트가 실제로 돌았는지 확인한다.

빌드 설정(배포 타깃, 번들 ID, 서명, entitlements)은 `Blink.xcodeproj/project.pbxproj`에 있다. 직접 편집은 최소한으로 하고, 바꾼 뒤에는 위 빌드로 확인한다.

## 제약

- Mac App Store로만 배포하므로 App Sandbox는 항상 켠다. 샌드박스에서 막히는 API는 쓰지 않는다. 이유는 [docs/adr/0001-app-sandbox-from-start.md](docs/adr/0001-app-sandbox-from-start.md) 참고.
- 구현은 사용자가 명시적으로 시작하라고 한 뒤에 한다. 기능 요청이나 제안에 대한 동의("그 안으로 가고 싶어" 등)는 구현 지시가 아니다. 먼저 설계·변경 범위를 정리해 보여 주고, "구현해", "시작해"처럼 분명한 컨펌을 받은 다음 코드를 고친다.
- 커밋은 항상 사용자의 확인을 받은 뒤에 한다. 작업이 끝나도 바로 커밋하지 말고, 무엇을 커밋할지 보여 주고 승인을 기다린다. 한 번 승인받았다고 다음 커밋까지 승인된 것으로 보지 않는다.

## 버전과 브랜치

- 버전은 `MAJOR.MINOR.PATCH`(`project.pbxproj`의 `MARKETING_VERSION`)이다. 기능을 추가하면 MINOR, 버그만 고치면 PATCH, 사용 방식이 바뀌는 큰 변화면 MAJOR를 올린다.
- 다음 버전 작업은 `main`에서 `release/<버전>` 브랜치(예: `release/1.1.0`)를 만들어 한다. 브랜치를 만들면 먼저 `MARKETING_VERSION`을 그 버전으로 올린다. `v1.1.0`이나 `1.1.0`처럼 버전만 쓴 이름은 태그와 겹치므로 브랜치 이름으로 쓰지 않는다.
- 한 버전에 브랜치 하나만 둔다. 기능별 브랜치는 나누지 않는다.
- 빌드 번호(`CURRENT_PROJECT_VERSION`)는 App Store Connect에 올릴 때마다 올린다.
- App Store에 제출한 버전은 `main`에 병합하고 그 커밋에 `v<버전>` 태그(예: `v1.1.0`)를 붙인다.
- 출시된 버전의 급한 버그는 그 버전 태그에서 `release/<다음 PATCH 버전>`(예: `v1.0.0`에서 `release/1.0.1`)을 만들어 고친다.
- 브랜치와 태그를 원격(`origin`)에 올리는 것은 커밋과 같이 사용자의 확인을 받은 뒤에 한다.

## 테스트

- 기능을 추가하거나 로직을 바꿀 때는 항상 테스트 코드를 같이 작성한다. 버그를 고칠 때는 그 버그를 재현하는 테스트를 먼저 쓴다.
- 테스트하기 쉬운 구조로 설계한다. 판단·계산·상태 변화(무엇을 보여 줄지, 값을 어떻게 고칠지, 크기를 얼마로 할지)는 AppKit과 시스템 API(TIS, `SMAppService`, `UserDefaults`, `NSPanel`)에 의존하지 않는 순수 함수나 값 타입으로 분리하고, 입력을 값으로 받아 결과를 값으로 돌려주게 한다. AppKit 쪽은 그 결과를 화면과 시스템에 반영하는 얇은 층으로 둔다. 지금 예시: `InputSourceTracker`(`next(current:previous:enabled:)` 포함), `SettingsWindow.snapped(_:)`, `HUD.panelWidth(fitting:from:ellipsis:maxWidth:)`, `HUDAppearance`(`select(_:)`·`colors(_:reduceTransparency:)`·`scaled(_:)`·`texts(from:to:)`), `InputSourceLabel.abbreviation(id:languages:name:)`, `CapsLockTracker`, `HUDColors.capsLock(on:)`, `HUDPosition`(`origin(size:in:margin:)`·`dragged(to:size:in:margin:snap:)`), `BadgePlacement`(`origin(size:pointer:in:)`), `CursorBadgeView.width(text:height:padding:)`.
- 화면처럼 단위 테스트로 확인할 수 없는 동작은 [docs/CHECKLIST.md](docs/CHECKLIST.md)에 항목을 추가한다(아래 '검증'의 기준을 따른다).

## 검증

[docs/CHECKLIST.md](docs/CHECKLIST.md)에 영역별(HUD, 포인터 배지, 설정 창, 메뉴·정보 창·첫 실행, 현지화, 출시) 확인 항목이 있다. 모든 항목은 Claude가 스크립트로 직접 확인하고, 사용자에게 확인을 넘기지 않는다.

- 코드를 바꿀 때마다 단위 테스트를 돌린다.
- 영역 코드를 바꿨으면 체크리스트에서 그 영역 항목만 확인한다. 매 작업마다 전체를 돌리지 않는다.
- App Store 제출 전(첫 출시와 업데이트마다)에는 전체를 확인한다.
- 체크리스트는 짧게 유지한다. 단위 테스트가 지키는 규칙, 화면 배치 같은 스펙, 스크립트로 확인할 수 없는 항목(시스템 설정·재로그인·다른 macOS 버전)은 넣지 않는다. 기능을 추가·삭제·변경하면 같은 작업 안에서 그 영역 항목을 고치되, 기존 항목에 합칠 수 있으면 합친다.

## 디자인 시스템

https://claude.ai/artifact/3n9WYkuynDn61C23fgZ8Nw (Blink 디자인 시스템: 색·타이포·간격 토큰, HUD·메뉴바·정보 창 규칙, 앱/메뉴바 아이콘). UI를 만들거나 고치기 전에 Artifact 도구의 `read`로 `project/README.md`를 읽고, 토큰 값은 `project/tokens.json`에서 가져온다. 값을 추측하지 않는다.

이 아티팩트는 늘 최신 설계(설계 중인 다음 버전 포함)다. 출시한 버전은 그 시점의 사본을 디자인 시스템 아티팩트로 따로 만들어 고정한다(예: [Blink 1.2.0](https://claude.ai/artifact/XLkVgM7oehKZFPEPWJgnKo)). 사본은 고치지 않는다. 다음 버전 작업을 시작하기 전에 직전 출시 버전의 사본을 만들고, 최신 README '버전' 표에 버전·사본 링크·바뀐 점 요약을 한 줄 추가한다.

## 제출 문안

App Store Connect에 넣는 문안과 스크린샷은 [docs/appstore/](docs/appstore/)에 버전 폴더, 그 아래 언어 폴더(App Store Connect 로케일: `en-US`, `ko`)로 둔다.

```
docs/appstore/<버전>/<언어>/
├── metadata.md             App Store Connect 화면 순서대로: 스크린샷 장면과 캡션·프로모션 텍스트·설명·이 버전에서 업그레이드된 사항·키워드·지원 URL 등·심사 노트, 끝에 앱 정보 화면의 이름·부제
└── <버전>-<언어>-<n>.png    그 버전에서 새로 만든 스크린샷(2880×1800), n은 그 버전 안에서 1부터
```

스크린샷은 새로 만들거나 바꾼 것만 그 버전 폴더에 넣는다. 올리는 순서와 파일은 metadata.md의 스크린샷 표(순서·파일·장면·캡션)에 적고, 이전 버전 것을 그대로 쓰면 그 버전 폴더의 경로를 적는다.

심사 노트는 언어별이 아니라 하나뿐이라 `en-US`에 영어로 쓰고, 다른 언어에는 참고용 번역만 둔다. 개인정보 처리방침의 원본은 [nostrss/blink-site](https://github.com/nostrss/blink-site)의 `privacy.md`다. 새 버전은 직전 버전 폴더를 복사해 고치고, 제출한 버전의 폴더는 바꾸지 않는다.

## 출시 심사 준비

App Store에 버전을 제출하기 전에는 [docs/RELEASE.md](docs/RELEASE.md)의 순서(보안·성능 검사 → 빌드 번호 → 문안 → 개인정보 처리방침 → 체크리스트 전체 → 스크린샷 → 리젝 사유 검토 → 커밋 → 사용자에게 넘기기 → 제출 뒤 병합·태그)를 따른다. 체크리스트를 스크립트로 확인하거나 스크린샷을 만들 때의 방법과 주의할 점도 그 파일에 있다.

## 기록 남기기

- `CONTEXT.md`: 이 프로젝트의 용어집. domain-modeling 스킬이 말하는 `GLOSSARY.md`는 이 저장소에서는 `CONTEXT.md`다. 형식과 규칙은 그 스킬을 따르고, 구현 세부사항은 넣지 않는다.
- `docs/adr/`: 아키텍처 결정 기록. `0001-slug.md`처럼 순번을 매긴다. 되돌리기 어렵고, 맥락 없이 보면 의아하며, 실제 트레이드오프가 있었던 결정만 기록한다.
- grilling 세션 중 용어가 정해지면 바로 `CONTEXT.md`에 반영하고, 위 기준에 맞는 결정이 나오면 ADR을 제안한다.
