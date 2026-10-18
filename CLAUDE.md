# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 프로젝트

Blink: macOS 메뉴바 앱. 한/영 입력소스가 바뀌면 화면 중앙에 "변경 전 → 변경 후"를 1초 띄운다. Swift + AppKit, 외부 라이브러리 없음. 사용자와는 한국어로 소통한다.

macOS 전용 타깃(최소 13.0, `LSUIElement`), 진입점은 `Blink/AppDelegate.swift`의 `static func main()`이다 (MainMenu nib 없음). 작업 순서와 진행 상황은 [docs/ROADMAP.md](docs/ROADMAP.md)에 있다.

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
- 테스트하기 쉬운 구조로 설계한다. 판단·계산·상태 변화(무엇을 보여 줄지, 값을 어떻게 고칠지, 크기를 얼마로 할지)는 AppKit과 시스템 API(TIS, `SMAppService`, `UserDefaults`, `NSPanel`)에 의존하지 않는 순수 함수나 값 타입으로 분리하고, 입력을 값으로 받아 결과를 값으로 돌려주게 한다. AppKit 쪽은 그 결과를 화면과 시스템에 반영하는 얇은 층으로 둔다. 지금 예시: `InputSourceTracker`(`next(current:previous:enabled:)` 포함), `SettingsWindow.snapped(_:)`, `HUD.panelWidth(fitting:from:ellipsis:maxWidth:)`, `HUDAppearance`(`select(_:)`·`colors(_:reduceTransparency:)`·`scaled(_:)`·`texts(from:to:)`), `InputSourceLabel.abbreviation(id:languages:name:)`, `HUDPosition`(`origin(size:in:margin:)`·`dragged(to:size:in:margin:snap:)`).
- 화면, 시스템 설정, 하드웨어처럼 단위 테스트로 확인할 수 없는 동작은 [docs/CHECKLIST.md](docs/CHECKLIST.md)에 항목을 추가한다.

## 검증

[docs/CHECKLIST.md](docs/CHECKLIST.md)에 영역별(입력소스 감지, HUD, 설정 창, 메뉴·로그인 항목, 정보 창·첫 실행, 현지화) 확인 항목이 있다.

- 코드를 바꿀 때마다 단위 테스트를 돌린다.
- 영역 코드를 바꿨으면 체크리스트에서 그 영역 항목만 확인한다. Claude 표시 항목은 직접 확인하고, 사용자 표시 항목은 확인을 요청한다. 매 작업마다 전체를 돌리지 않는다.
- App Store 제출 전(첫 출시와 업데이트마다)에는 전체를 확인한다.
- 기능을 추가·삭제·변경하면 같은 작업 안에서 `docs/CHECKLIST.md`도 고친다. 새 기능은 확인 항목과 확인 주체(Claude/사용자/테스트)를 추가하고, 없어진 기능의 항목은 지우고, 동작이 바뀐 항목은 문구를 맞춘다.

## 디자인 시스템

https://claude.ai/artifact/3n9WYkuynDn61C23fgZ8Nw (Blink 디자인 시스템: 색·타이포·간격 토큰, HUD·메뉴바·정보 창 규칙, 앱/메뉴바 아이콘). UI를 만들거나 고치기 전에 Artifact 도구의 `read`로 `project/README.md`를 읽고, 토큰 값은 `project/tokens.json`에서 가져온다. 값을 추측하지 않는다.

## 스토어 스크린샷

https://claude.ai/artifact/XGEmszyZoGwdewcuE5UkAc (Blink 스토어 스크린샷: Mac App Store에 올린 스크린샷을 앱 버전·언어별로 모은 페이지). 새 버전의 스크린샷을 만들면 이 아티팩트에 버전을 추가하고 이전 버전은 남긴다. 캡션과 장면은 [docs/APPSTORE.md](docs/APPSTORE.md)의 '스크린샷'에 있다.

## 기록 남기기

- `CONTEXT.md`: 이 프로젝트의 용어집. domain-modeling 스킬이 말하는 `GLOSSARY.md`는 이 저장소에서는 `CONTEXT.md`다. 형식과 규칙은 그 스킬을 따르고, 구현 세부사항은 넣지 않는다.
- `docs/adr/`: 아키텍처 결정 기록. `0001-slug.md`처럼 순번을 매긴다. 되돌리기 어렵고, 맥락 없이 보면 의아하며, 실제 트레이드오프가 있었던 결정만 기록한다.
- grilling 세션 중 용어가 정해지면 바로 `CONTEXT.md`에 반영하고, 위 기준에 맞는 결정이 나오면 ADR을 제안한다.
