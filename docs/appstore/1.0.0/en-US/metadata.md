# 1.0.0 영어(미국) 메타데이터

App Store Connect에서 언어를 영어(미국)로 두고 붙여 넣는 문안. 스크린샷은 아래 '스크린샷' 표의 순서대로 올린다.

## 이름 (30자)

Blink: Input Language Alert

"Blink"만으로 된 이름은 이미 쓰이고 있어 "Blink: …" 꼴로 등록했다(2026-10-17). 한국어 이름은 한영에만 묶이지 않게 "입력 언어"로 쓰고, 이름·부제에 있는 낱말(입력, 언어, 알림, 한영, 전환)은 키워드에 다시 넣지 않는다(검색은 이름·부제·키워드를 합쳐서 본다). 영어 이름은 처음에 "Blink: Input Source HUD"로 만들었다가 낯선 "HUD"를 빼고 한국어와 같은 뜻으로 바꿨다(2026-10-18).

## 부제 (30자)

Language switch, now visible

## 키워드 (100자)

keyboard,layout,input source,IME,switch,indicator,korean,japanese,chinese,menu bar,typo,toggle

## 프로모션 문구 (170자)

Not sure your keyboard actually switched? Blink shows it on screen the moment it changes. Place it and style it the way you like.

## 설명

Ever typed a whole sentence on your Mac, looked up, and found it came out in the wrong language? You notice too late, delete it, and type it all again.

Blink sits quietly in your menu bar. The moment your input source changes, it shows what you switched from and to, like "ABC → 2-Set Korean", right on screen. Just for the blink of an eye. It never covers your work, and clicks pass straight through.

GREAT FOR
• Developers, writers and translators who switch languages all day
• Anyone using Korean, Japanese, Chinese or other input methods alongside English
• People who look at the middle of the screen more than at the menu bar

WHAT YOU CAN DO
• Shows on the screen where your mouse is, above full-screen apps and on every Space
• Display time from 0.5 to 5 seconds
• Pick one of nine spots, or drag it anywhere
• Themes: Default, High Contrast, Dracula, Gruvbox, Rosé Pine, or your own colors
• Size, corners, font weight, and an option to show only the new language
• Follows Reduce Transparency and Reduce Motion
• Launch at login, only if you want it

PRIVACY
Blink collects nothing, never connects to the internet, and needs no special permissions. It only reads the name of the current input source.

Available in English, Korean, Japanese, Chinese (Simplified and Traditional), Russian, German, French, Spanish, and Portuguese (Brazil).

## 스크린샷

2880×1800. 실제 화면 캡처를 잘라 파란 배경(앱 아이콘 색) 위에 캡션과 함께 얹었다. 버전별 모음은 [Blink 스토어 스크린샷](https://claude.ai/artifact/XGEmszyZoGwdewcuE5UkAc) 아티팩트. "앱 미리보기"는 동영상 칸이라 쓰지 않고, 이미지는 "앱 스크린샷"에 표의 순서대로 올린다. 파일 이름의 번호는 그 버전에서 새로 만든 순서다.

| 순서 | 파일 | 장면 | 캡션 |
|---|---|---|---|
| 1 | `1.0.0-en-US-1.png` | 바탕화면 위 HUD(크게) | Language switch, now visible / See the moment it changes, right on screen. |
| 2 | `1.0.0-en-US-2.png` | 설정 '위치' | Put it anywhere / Pick one of nine spots, or drag the HUD where you want it. |
| 3 | `1.0.0-en-US-3.png` | 설정 '모양' | Make it yours / Change size, corners and font weight, with light and dark previews. |

## 심사 노트

App Review Information > Notes에 넣는다. 심사 노트는 언어별이 아니라 하나뿐이라 영어로만 쓴다. 한국어 번역은 `ko/metadata.md`에 있다.

Blink is a menu bar app (no Dock icon). It shows a short on-screen HUD whenever the keyboard input source changes.

IMPORTANT: The HUD only appears when the input source actually changes. If the review Mac has a single input source, nothing will appear. Please add a second one first:

1. Open System Settings > Keyboard > Input Sources > Edit…
2. Click "+", choose Korean > 2-Set Korean (any other language also works), and click Add.
3. Switch input sources with Control-Space (or the input menu in the menu bar, or the Globe/Caps Lock key if configured).
4. A HUD showing "previous → new" (for example "ABC → 2-Set Korean") appears at the center of the screen for one second.

Settings: On first launch the Settings window opens automatically. Afterwards, click the Blink icon (•→) in the menu bar and choose "Settings…" (⌘,). Settings has three panes: General (show HUD, display time, launch at login), Position, and Appearance.

If only one input source is installed, the Position pane shows a note explaining that the HUD will not appear.

Launch at login uses SMAppService and is off by default; it is only enabled when the user turns it on.

Blink runs in the App Sandbox, makes no network connections, collects no data, and requests no permissions (no Accessibility or Input Monitoring). It only reads the current input source name through the Text Input Sources API.
