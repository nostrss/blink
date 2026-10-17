# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 프로젝트

Blink: macOS 메뉴바 앱. 한/영 입력소스가 바뀌면 화면 중앙에 "변경 전 → 변경 후"를 1초 띄운다. Swift + AppKit, 외부 라이브러리 없음. 사용자와는 한국어로 소통한다.

macOS 전용 타깃(최소 13.0, `LSUIElement`), 진입점은 `Blink/AppDelegate.swift`의 `static func main()`이다 (MainMenu nib 없음). 작업 순서와 진행 상황은 [docs/ROADMAP.md](docs/ROADMAP.md)에 있다.

## 빌드

`xcode-select`가 Command Line Tools를 가리키고 있어 `xcodebuild`를 그냥 실행하면 실패한다. `DEVELOPER_DIR`를 지정한다:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Blink.xcodeproj -scheme Blink -configuration Debug -derivedDataPath build build
```

결과물: `build/Build/Products/Debug/Blink.app` (`build/`는 gitignore됨). 테스트 타깃은 아직 없다.

빌드 설정(배포 타깃, 번들 ID, 서명, entitlements)은 `Blink.xcodeproj/project.pbxproj`에 있다. 직접 편집은 최소한으로 하고, 바꾼 뒤에는 위 빌드로 확인한다.

## 제약

- Mac App Store로만 배포하므로 App Sandbox는 항상 켠다. 샌드박스에서 막히는 API는 쓰지 않는다. 이유는 [docs/adr/0001-app-sandbox-from-start.md](docs/adr/0001-app-sandbox-from-start.md) 참고.
- 커밋은 항상 사용자의 확인을 받은 뒤에 한다. 작업이 끝나도 바로 커밋하지 말고, 무엇을 커밋할지 보여 주고 승인을 기다린다. 한 번 승인받았다고 다음 커밋까지 승인된 것으로 보지 않는다.

## 디자인 시스템

https://claude.ai/artifact/3n9WYkuynDn61C23fgZ8Nw (Blink 디자인 시스템: 색·타이포·간격 토큰, HUD·메뉴바·정보 창 규칙, 앱/메뉴바 아이콘). UI를 만들거나 고치기 전에 Artifact 도구의 `read`로 `project/README.md`를 읽고, 토큰 값은 `project/tokens.json`에서 가져온다. 값을 추측하지 않는다.

## 기록 남기기

- `CONTEXT.md`: 이 프로젝트의 용어집. domain-modeling 스킬이 말하는 `GLOSSARY.md`는 이 저장소에서는 `CONTEXT.md`다. 형식과 규칙은 그 스킬을 따르고, 구현 세부사항은 넣지 않는다.
- `docs/adr/`: 아키텍처 결정 기록. `0001-slug.md`처럼 순번을 매긴다. 되돌리기 어렵고, 맥락 없이 보면 의아하며, 실제 트레이드오프가 있었던 결정만 기록한다.
- grilling 세션 중 용어가 정해지면 바로 `CONTEXT.md`에 반영하고, 위 기준에 맞는 결정이 나오면 ADR을 제안한다.
