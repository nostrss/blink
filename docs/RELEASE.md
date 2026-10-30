# 출시 심사 준비

App Store에 새 버전을 제출하기 전에 이 순서대로 한다. 단계마다 끝난 조건을 채운 뒤 다음 단계로 간다. 커밋·푸시는 CLAUDE.md의 규칙대로 사용자 확인을 받는다.

## 순서

0. **보안·성능 검사**: 코드를 고칠 수 있는 마지막 때라 제일 먼저 한다. 범위는 직전 출시 태그부터의 변경(`git diff v<직전 버전>..HEAD`)과 그 변경이 닿는 기존 코드다.
   - **보안**: entitlements가 샌드박스 외에 필요 없는 권한을 갖지 않는가, 네트워크 접속이 없는가, 입력한 내용·키 순서처럼 저장하지 않기로 한 것을 저장하거나 로그(`NSLog`, `print`)에 남기지 않는가, 저장 파일(`Statistics.json`, `UserDefaults`)이 깨져 있거나 비정상 값이어도 죽지 않고 복구하는가, 비밀 값이 저장소에 없는가. `/security-review` 스킬을 함께 돌린다.
   - **성능**: 사용자가 느낄 불편(버벅임, 배터리, 메모리)을 찾는다. 자주 불리는 경로(전역 마우스 이벤트 처리, 타이머, 통계 창 갱신, HUD 표시)의 할 일이 가벼운가, 기록이 시간이 지나도 무한히 쌓이지 않는가, 저장이 너무 잦지 않은가를 코드로 보고, 실제로도 잰다: 앱을 띄워 가만히 둘 때와 포인터를 계속 움직이고 한/영을 연속 전환할 때 `ps -o %cpu,rss -p <pid>`(또는 `top -pid`)로 CPU·메모리를 보고, 몇 분 뒤 메모리가 계속 늘지 않는지 본다.
   - 찾은 것은 심각도와 함께 보여 주고, 고치기로 하면 테스트를 같이 써서 고친다(CLAUDE.md '테스트'). 끝난 조건: 보안·성능 항목마다 '문제 없음' 또는 고침·사용자 결정이 적혀 있고, 잰 CPU·메모리 숫자가 남아 있다.
1. **빌드 번호**: `project.pbxproj`의 `CURRENT_PROJECT_VERSION`을 직전 업로드보다 1 올린다(네 군데 모두). 끝난 조건: `test` 빌드가 통과하고, 결과물 `Info.plist`의 `CFBundleShortVersionString`·`CFBundleVersion`이 이번 버전·빌드 번호다.
2. **문안**: 직전 버전의 `docs/appstore/<버전>/`을 복사해 고친다(폴더 형식은 CLAUDE.md '제출 문안'). 버전에서 달라진 기능이 닿는 섹션을 모두 고친다: 머리말의 '달라진 곳' 한 줄, 스크린샷 표, 프로모션 텍스트, 설명(기능 줄·개인정보 문단), 이 버전에서 업그레이드된 사항, 버전·빌드, 심사 노트(설정 화면 수, 'New in <버전>', 새로 쓰는 시스템 API와 그 이유). 끝난 조건: en-US·ko 둘 다 고쳤고, 글자 수가 제한 안이다(프로모션 170, 설명·업그레이드 사항 4000, 키워드 100).
3. **개인정보 처리방침**: 새 기능이 읽거나 저장하는 것이 [nostrss/blink-site](https://github.com/nostrss/blink-site)의 `privacy.md` 문구와 맞는지 본다. 어긋나면 영어·한국어 수정안을 보여 주고, 승인받으면 시행일을 바꿔 푸시한다. 끝난 조건: https://nostrss.github.io/blink-site/privacy 에 새 문구가 보인다(Pages 반영에 1분쯤 걸린다).
4. **체크리스트 전체**: [CHECKLIST.md](CHECKLIST.md)의 모든 항목을 아래 '스크립트로 확인하기'대로 확인한다. 끝난 조건: 항목마다 통과, 또는 왜 판단하지 못했는지가 정리돼 있다.
5. **스크린샷**: 이번 버전의 대표 기능이 기존 스크린샷에 없으면 새로 만들지 사용자에게 묻는다. 만들면 아래 '스크린샷 만들기'대로 en-US·ko 한 장씩 만들어 그 버전 폴더에 넣고 metadata.md 표에 넣는다. 끝난 조건: 2880×1800이고, Blink 말고 다른 앱의 아이콘·창·이름이 보이지 않는다.
6. **리젝 사유 검토**: 준비한 문안(metadata.md 전부, 심사 노트 포함)과 이번 버전 스크린샷을 [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)에 비춰 리젝될 만한 곳을 찾는다. 적어도 이것들을 본다: 설명·스크린샷의 기능이 이 빌드에 실제로 있는가(2.3.1), 스크린샷이 앱을 쓰는 실제 화면인가(2.3.3), 다른 회사의 앱·아이콘·상표나 다른 플랫폼 이름이 없는가(2.3.7, 2.3.10, 5.2), 키워드에 경쟁 앱 이름이 없는가(2.3.7), 개인정보 문구·처리방침·App Privacy 답변·실제 동작이 서로 맞는가(5.1.1, 5.1.2), 심사자가 기능을 재현할 수 있게 심사 노트가 설정 방법과 새 시스템 API의 이유를 설명하는가(2.1). 찾은 것은 가이드라인 번호와 함께 보여 주고 고친다. 끝난 조건: 위 항목마다 '문제 없음' 또는 고침·사용자 결정이 적혀 있다.
7. **커밋**: 빌드 번호와 `docs/appstore/<버전>/`을 `chore: prepare <버전> for App Store submission`으로 커밋한다.
8. **사용자에게 넘기기**: 업로드(Xcode Archive), App Store Connect 입력, 심사 제출은 사용자가 한다. metadata.md 경로, 스크린샷 순서, 고를 빌드(`<버전> (<빌드>)`)를 알려 준다.
9. **제출 뒤**: 사용자가 제출했다고 하면 확인을 받고 `release/<버전>`을 푸시한 뒤 `main` 대상 PR(`gh pr create --base main`)을 만든다. 로컬에서 `main`에 병합하거나 `main`에 바로 푸시하지 않는다. PR이 병합되면 그 병합 커밋에 `v<버전>` 태그를 붙여 푸시하고, CHANGELOG의 그 버전 부분으로 GitHub Release를 만든다. 디자인 시스템 사본은 다음 버전을 시작하기 전에 만든다(CLAUDE.md '디자인 시스템').

## 스크립트로 확인하기

화면을 조작하기 전에 사용자에게 "마우스와 키보드를 움직이지 말아 주세요"라고 걸리는 시간과 함께 알리고, 끝나면 다시 써도 된다고 알린다.

시작 전에 백업하고, 끝나면 되돌린다:

- 번들 ID는 Debug 빌드(`Blink Dev.app`, 프로세스 이름 `Blink Dev`)가 `com.jintaek.blink.dev`, Release 빌드가 `com.jintaek.blink`다. 아래 명령은 확인하는 빌드의 번들 ID로 쓴다.
- 설정: `defaults export com.jintaek.blink <파일>` → `defaults import com.jintaek.blink <파일>`. 샌드박스 컨테이너 plist를 직접 고치지 않는다. 앱 인자(`--args -hudDuration 1`)로 덮는 쪽이 덜 위험하다.
- 통계: `~/Library/Containers/com.jintaek.blink/Data/Library/Application Support/Statistics.json`을 복사해 둔다.
- 다크/라이트, 숨긴 앱, 입력소스: 바꿨으면 원래대로 돌린다.

도구(스크래치패드에 Swift로 만들어 쓴다):

- 입력소스 전환: `TISSelectInputSource`. Caps Lock: `IOHIDSetModifierLockState`.
- 포인터·클릭·스크롤: `CGEvent`를 `.cghidEventTap`으로 보낸다. 앱을 막 띄운 직후에는 첫 이벤트를 놓칠 수 있어 이동은 2–3번 보낸다.
- 창 위치·크기: `CGWindowListCopyWindowInfo`. HUD·배지는 레벨 1000, 일반 창은 0이다.
- 메뉴와 설정 창: System Events로 `menu bar item 1 of menu bar 1`(Blink 메뉴), `first window whose subrole is "AXStandardWindow"`(설정 창), 사이드바는 `table 1 of scroll area 1 of splitter group 1`. 버튼은 `entire contents`로 경로를 찾는다.

알아 둘 것:

- 다크/라이트는 macOS 26에서 앱 인자가 듣지 않는다. `tell application "System Events" to tell appearance preferences to set dark mode to false`로 시스템 모드를 바꾸고 끝나면 되돌린다.
- `pkill`로 끝내면 `applicationWillTerminate`가 불리지 않아 통계가 저장되지 않는다. 저장을 확인할 때는 메뉴의 "Blink 종료"로 끝낸다.
- `defaults read`는 앱이 방금 쓴 값을 늦게 보여 줄 때가 있다. 앱을 끝낸 뒤 다시 읽는다.
- 스크립트 클릭으로 연 창은 앞으로 오지 않는다(macOS가 활성화를 막는다). 창이 열렸는지와 앞으로 왔는지는 따로 본다.
- 라이트/다크 중 시스템이 아닌 쪽과 긴 입력소스 이름은 시스템 설정을 바꿔야 해서, 다크/라이트만 위 방법으로 보고 긴 이름은 단위 테스트(`HUD.panelWidth`)에 맡긴다.

## 스크린샷 만들기

기존 스크린샷과 같은 모양: 위쪽 파란 그라데이션(앱 아이콘 색 `#5e9cf7` → `#2f68d6`)에 흰 제목·부제, 아래에 실제 화면 캡처를 위 모서리만 둥근 판으로 얹고 아래는 캔버스 밖으로 잘린다.

0. Release 빌드(`-configuration Release`)로 찍는다. Debug 빌드는 메뉴바 아이콘에 개발용 점이 있다.
1. 시스템을 라이트 모드로 바꾼다(기존 스크린샷이 모두 라이트).
2. 보이는 앱 목록을 저장하고 모두 숨긴다(`set visible of every process whose visible is true and background only is false to false`). 되돌릴 때 이름에 공백이 있는 앱(`Google Chrome`)도 빠뜨리지 않는다.
3. 통계처럼 숫자가 보이는 화면은 목데이터를 `Statistics.json`에 넣는다. 30일 증감이 어색하지 않게 75일치를 만든다.
4. en-US는 `--args -AppleLanguages "(en)" -AppleLocale en_US`(단위가 mi·ft로 나온다), ko는 `"(ko)" -AppleLocale ko_KR`로 띄운다.
5. 메뉴를 펼친 장면은 AX 클릭 대신 Blink 메뉴바 아이콘 위치(AX `position`·`size`)에 `CGEvent` 클릭을 보내서 연다. `screencapture -R`로는 열린 메뉴가 찍히지 않을 때가 있어, 화면 전체를 찍고 `sips -c <높이> <폭> --cropOffset <y> <x>`로 자른다.
6. 메뉴바에 보이는 다른 앱 아이콘과 입력소스 아이콘은 같은 줄의 빈 하늘 픽셀로 덮는다. 메뉴 판 위쪽 모서리를 덮지 않도록 덮는 높이를 메뉴바 줄까지만 잡는다.
7. 1440×900 HTML 페이지(제목 56px 700, 부제 22px, 캡처 판 폭 1224px, 위 228px)에 얹어 Chrome headless로 2배 렌더링한다: `"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --hide-scrollbars --force-device-scale-factor=2 --window-size=1440,900 --screenshot=<출력> <html>`.
8. 결과를 `docs/appstore/<버전>/<언어>/<버전>-<언어>-<n>.png`로 저장하고, 캡션을 metadata.md 표에 그대로 적는다.
