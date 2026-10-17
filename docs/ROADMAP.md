# Blink 로드맵

단계마다 끝나면 빌드하고, 완료 기준을 직접 확인한 다음 다음 단계로 넘어간다. 설계 근거는 [ADR 0001](adr/0001-app-sandbox-from-start.md), UI 값은 [디자인 시스템](https://claude.ai/artifact/3n9WYkuynDn61C23fgZ8Nw)을 따른다.

## 0. 프로젝트 설정

- 멀티플랫폼 템플릿을 macOS 전용으로 바꾼다 (`SDKROOT = macosx`, iOS·visionOS 설정 제거).
- 배포 타깃 26.6 → 13.0 (`SMAppService`의 최소 버전).
- 번들 ID `com.jintaek.Blink` → `com.jintaek.blink`.
- `LSUIElement = YES`로 Dock 아이콘을 없앤다. 쓰지 않는 파일 접근 엔타이틀먼트는 제거한다.
- SwiftUI 템플릿을 AppKit `AppDelegate`로 교체하고 `ContentView.swift`를 삭제한다.

**완료 기준**: 빌드가 되고, 실행하면 Dock 아이콘과 창 없이 프로세스만 떠 있다.

## 1. 메뉴바 골격

- `NSStatusItem`에 `menubar-icon.svg`를 템플릿 이미지로 넣는다.
- 메뉴: "언어 전환 표시"(체크), "정보…", 구분선, "Blink 종료".
- 토글 상태는 `UserDefaults` 키 하나에 저장한다. 꺼지면 아이콘을 `appearsDisabled`로 표시한다.

**완료 기준**: 아이콘이 라이트/다크 모드에서 모두 보이고, 토글 상태가 재실행 후에도 유지되고, 종료가 동작한다.

## 2. 입력소스 감지

- `kTISNotifySelectedKeyboardInputSourceChanged`를 구독하고, 현재 입력소스의 로컬라이즈된 이름을 읽는다.
- 직전 값과 같으면 무시한다.

**완료 기준**: 샌드박스를 켠 상태에서 한/영을 전환할 때마다 "변경 전 → 변경 후"가 로그에 정확히 한 번 찍힌다.

## 3. HUD 오버레이

- 테두리 없는 투명 `NSPanel` 하나를 재사용한다. 최상위 레벨, 마우스 이벤트 무시, 모든 Space와 전체화면 위에 표시한다.
- 마우스가 있는 화면 중앙에 띄운다. 1.0초 유지한 뒤 0.3초 동안 페이드아웃한다. 연속으로 전환되면 타이머만 리셋한다.
- 색·글꼴·간격·모서리는 디자인 시스템의 `hud-*` 토큰을 쓴다.

**완료 기준**: 전환하면 HUD가 뜨고, 토글이 꺼져 있으면 뜨지 않는다.

## 4. 자동 실행과 정보·첫 실행 창

- `SMAppService.mainApp`으로 로그인 항목을 등록한다.
- 정보·첫 실행 창: "무엇을 하는 앱인지 + 켜고 끄는 법"만 담는다. App Store 심사에도 필요하다.

**완료 기준**: 재로그인 후 자동으로 실행되고, 첫 실행 때만 안내 창이 뜨며, "정보…"로 다시 열 수 있다.

## 5. 검증

한/영 전환, 세 번째 입력소스 추가, 전체화면 앱 위, 멀티 모니터(마우스가 있는 화면), 토글 off, 빠른 연속 전환, 라이트/다크 모드.

## 6. A · 직접 배포

Archive → Developer ID로 서명 → 공증 → `xcrun stapler staple` → zip/DMG → GitHub Release.

**완료 기준**: 다른 Mac에서 내려받아 Gatekeeper 경고 없이 실행된다.

## 7. B · Mac App Store

App Store Connect에 앱 등록 → 스크린샷·설명·개인정보 처리방침 URL → 심사 노트에 동작 방식 설명 → 제출.

## 열린 질문

- 로그인 항목을 항상 켜 둘지, 메뉴에서 켜고 끄게 할지 (디자인 시스템의 메뉴에는 해당 항목이 없음).
- 정보 창을 AppKit으로 만들지 SwiftUI로 만들지.
- 감지 로직을 단위 테스트할지, 수동 검증만으로 충분한지.
