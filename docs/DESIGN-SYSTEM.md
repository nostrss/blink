# 디자인 시스템 관리

Blink의 화면 규칙과 토큰은 디자인 시스템 아티팩트에 둔다. 이 문서는 그 아티팩트를 읽고 고치는 방법이다. 커밋·푸시 규칙은 CLAUDE.md를 따른다(아티팩트 게시는 커밋이 아니므로 따로 승인받지 않는다).

- **최신**: https://claude.ai/artifact/3n9WYkuynDn61C23fgZ8Nw — 늘 최신 설계(설계 중인 다음 버전 포함)
- **출시 사본**: 출시한 버전마다 고정한 사본. 링크는 최신 README의 '버전' 표에 있다. 사본은 고치지 않는다.

## 구조

'Design System' 타입으로 만든 아티팩트다. 내용은 모두 `project/` 아래 파일이다.

| 경로 | 내용 |
| --- | --- |
| `project/design-system.json` | 인덱스. 제목, `lastChange`, 로고 에셋 기록(`assetGroups`) |
| `project/README.md` | 브랜드 북. 원칙, 버전 표, 화면별 요약. 다른 에이전트는 여기서부터 읽는다 |
| `project/tokens.json` | 색·타이포·간격·모서리 토큰. 앱의 `Blink/Tokens.swift`가 이 값을 옮겨 쓴다 |
| `project/components/<이름>/README.md` | 화면별 자세한 규칙: HUD, CursorBadge, MenuBar, SettingsWindow, StatsWindow, AboutWindow |
| `project/components/<이름>/preview.html` | 그 화면의 프리뷰. 라이트·다크와 상태별 장면을 그린다 |
| `project/components/Cover/preview.html` | Overview 맨 위 표지 |
| `project/versions/<버전>.md` | 설계 중인 버전의 바뀐 점, 토큰, 저장값. 보류한 설계(`hold-*.md`)도 여기에 둔다 |

`project/tokens.css`, `project/api/`, `project/manifest.json`은 페이지가 만드는 파일이라 직접 쓰지 않는다. `project/` 밖(`index.html`, `artifact-type/`, `SKILL.md`)은 타입의 파일이라 쓸 수 없다. 형식의 자세한 규칙은 아티팩트의 `artifact-type/reference/format.md`에 있다.

## 읽기

- UI를 만들거나 고치기 전에 Artifact 도구의 `read`(`path: "project/README.md"`)로 README를 읽고, 그 화면의 컴포넌트 README를 읽는다.
- 토큰 값은 `project/tokens.json`에서 가져온다. 값을 추측하지 않는다.
- `read`에 `paths`로 여러 파일을 한 번에 받을 수 있다. 파일은 스크래치패드의 `artifact-files/<id>/project/...`에 저장되고, 그 복사본을 고쳐서 다시 올린다.

## 고치기

1. **읽기**: 고칠 파일과 `project/design-system.json`을 같은 `read`로 받는다. 받은 버전 id를 기억해 둔다.
2. **고치기**: 받은 복사본을 그 자리에서 고친다. 요청받은 것만 바꾼다. `tokens.json`은 늘 파일 전체를 올린다.
3. **인덱스**: `design-system.json`의 `lastChange`만 고친다(`by` "Woo jin taek", `via` "Claude Code", `at` 지금(UTC), `note` 한 줄 요약). 다른 키는 그대로 둔다.
4. **올리기 직전**: `list`(`scope: "files"`)로 버전 id가 1단계와 같은지 확인한다. 다르면 누가 그 사이에 고친 것이므로 다시 읽고 2단계부터 한다.
5. **올리기**: 한 번의 publish로 보낸다. `url`은 최신 링크, `root`는 `artifact-files/<id>` 폴더, `file_path`는 인덱스의 절대 경로, `files`는 고친 파일만 `{"project/…": "project/…"}`로 넣는다. 보내지 않은 파일은 그대로 남는다.
6. **확인**: 브라우저로 페이지를 열어 고친 컴포넌트까지 스크롤해 본다(아래 '프리뷰').

## 무엇을 같이 고치나

| 바뀐 것 | 고칠 곳 |
| --- | --- |
| 화면 규칙(배치, 간격, 문구) | 그 컴포넌트의 README와 preview.html. 요약이 바뀌면 루트 README의 그 화면 문단 |
| 토큰 추가·값 변경 | `tokens.json`, 그 토큰을 쓰는 컴포넌트 README, 앱의 `Blink/Tokens.swift` |
| 설계 중인 버전의 변경 | `versions/<버전>.md`의 '바뀐 점', 루트 README '버전' 표의 그 버전 줄 |
| 앱 코드의 UI 변경 | 같은 작업 안에서 디자인 시스템도 고쳐, 코드와 설계가 어긋나지 않게 한다 |

## 쓰는 법

- 한국어로 쓰고, 규칙은 토큰 이름으로 말한다(`line` 1pt, `radius-md`). 값만 적지 않는다.
- 버전에 따라 달라진 규칙에는 '(1.4.0부터)', '(1.3.0까지 …)'를 붙인다. 지운 규칙은 언제 왜 지웠는지 한 줄 남긴다(예: 메뉴 단축키).
- 컴포넌트 README의 첫 문장은 그 화면의 요약이다(페이지가 목록에 쓴다).
- 사용자에게 보이는 이름을 그대로 쓴다('포인터', '키 입력'). 쓰지 않는 말도 적어 둔다('커서', '타').
- 토큰 이름은 17자 이내로 짓는다. 더 길면 Colors 화면의 이름 칸에서 잘린다.
- 군더더기를 넣지 않는다. 안내 줄·각주·숨기기 같은 장치는 설계에도 넣지 않는다.

## 프리뷰

- 1행은 마커다: `<!-- @dsCard group="…" height=120 width=… subtitle="…" -->`. `width`는 레이아웃 폭(px)이고, 칸보다 넓으면 줄여서 보인다.
- 프리뷰 높이는 내용에 맞춰 늘어나지만 **4,000px까지**다. 넘으면 프리뷰 안에 스크롤바가 생긴다. 장면이 많으면 2단으로 놓고 `width`를 그 폭으로 준다(SettingsWindow `width=1260`, `.stack`을 `column-count:2`, StatsWindow `width=1000`).
- 높이 재기: 페이지 안의 프리뷰는 다른 출처 프레임이라 스크립트로 잴 수 없다. `tokens.css`와 `preview.html`을 붙인 로컬 페이지를 스크래치패드에 만들어 `python3 -m http.server`로 띄우고, 그 폭의 iframe에서 `documentElement.scrollHeight`를 잰다. 다 쓴 서버와 탭은 닫는다.
- 프리뷰는 실제 앱을 그대로 따라 그린다. 앱에서 뺀 요소(구분선 등)는 프리뷰에서도 뺀다.

## 버전 사본

다음 버전 작업을 시작하기 전에 직전 출시 버전의 사본을 만든다.

1. 최신 아티팩트의 `project/` 파일을 모두 읽는다.
2. 'Design System' 타입으로 새 아티팩트(제목 'Blink <버전>')를 만들고 그 파일들을 그대로 올린다. 로고는 `assetGroups` 기록과 함께 에셋으로 옮긴다.
3. 최신 README '버전' 표에 버전·사본 링크·바뀐 점 요약을 한 줄 추가한다.

사본은 그 뒤로 고치지 않는다.
