# 1.1.0 영어(미국) 메타데이터

App Store Connect에서 언어를 영어(미국)로 두고 붙여 넣는 문안. 스크린샷은 아래 '스크린샷' 표의 순서대로 올린다. 1.0.0과 달라진 곳은 이 버전의 업데이트 내용(새로 씀)과 설명의 'WHAT YOU CAN DO'·'PRIVACY'다.

## 이름 (30자)

Blink: Input Language Alert

## 부제 (30자)

Language switch, now visible

## 키워드 (100자)

keyboard,layout,input source,IME,switch,indicator,korean,japanese,chinese,menu bar,typo,toggle

## 프로모션 문구 (170자)

Not sure your keyboard actually switched? Blink shows it on screen the moment it changes. Place it and style it the way you like.

## 이 버전의 업데이트 내용 (4000자)

What's new in 1.1
• Display Style: show input sources by name or as a short label like "EN" or "한". Hide the previous source to get a tiny one-label badge.
• Caps Lock HUD: see "⇪ On" or "⇪ Off" whenever you press Caps Lock. Turn it on in Settings > General.
• Pointer badge: keep the current input source right next to your mouse pointer. Pick its side and size, and let it hide when the pointer stops. Turn it on in Settings > Pointer.
• Hiding the previous source now hides the arrow too.

Still no special permissions needed.

## 설명

Ever typed a whole sentence on your Mac, looked up, and found it came out in the wrong language? You notice too late, delete it, and type it all again.

Blink sits quietly in your menu bar. The moment your input source changes, it shows what you switched from and to, like "ABC → 2-Set Korean", right on screen. Just for the blink of an eye. It never covers your work, and clicks pass straight through.

GREAT FOR
• Developers, writers and translators who switch languages all day
• Anyone using Korean, Japanese, Chinese or other input methods alongside English
• People who look at the middle of the screen more than at the menu bar

WHAT YOU CAN DO
• Shows on the screen where your mouse is, above full-screen apps and on every Space
• Full names or short labels like "EN" and "한"
• Pointer badge: the current input source always next to your mouse pointer, if you want it
• Caps Lock alert: "⇪ On" or "⇪ Off" when you press Caps Lock, if you want it
• Display time from 0.5 to 5 seconds
• Pick one of nine spots, or drag it anywhere
• Themes: Default, High Contrast, Dracula, Gruvbox, Rosé Pine, or your own colors
• Size, corners, font weight, and an option to show only the new language
• Follows Reduce Transparency and Reduce Motion
• Launch at login, only if you want it

PRIVACY
Blink collects nothing, never connects to the internet, and needs no special permissions. It only reads the current input source, the Caps Lock state and where your pointer is, to draw them on screen.

Available in English, Korean, Japanese, Chinese (Simplified and Traditional), Russian, German, French, Spanish, and Portuguese (Brazil).

## 스크린샷

2880×1800. 실제 화면 캡처를 잘라 파란 배경(앱 아이콘 색) 위에 캡션과 함께 얹었다. 버전별 모음은 [Blink 스토어 스크린샷](https://claude.ai/artifact/XGEmszyZoGwdewcuE5UkAc) 아티팩트. "앱 미리보기"는 동영상 칸이라 쓰지 않고, 이미지는 "앱 스크린샷"에 표의 순서대로 올린다. 1–3은 1.0.0 것을 그대로 쓰고, 4는 이 버전에서 새로 만들었다. 파일 이름의 번호는 그 버전에서 새로 만든 순서다.

| 순서 | 파일 | 장면 | 캡션 |
|---|---|---|---|
| 1 | `../../1.0.0/en-US/1.0.0-en-US-1.png` | 바탕화면 위 HUD(크게) | Language switch, now visible / See the moment it changes, right on screen. |
| 2 | `../../1.0.0/en-US/1.0.0-en-US-2.png` | 설정 '위치' | Put it anywhere / Pick one of nine spots, or drag the HUD where you want it. |
| 3 | `../../1.0.0/en-US/1.0.0-en-US-3.png` | 설정 '모양' | Make it yours / Change size, corners and font weight, with light and dark previews. |
| 4 | `1.1.0-en-US-1.png` | 설정 '포인터'와 바탕화면에서 포인터를 따라가는 배지 | Right by your pointer / Keep the current input source next to your mouse pointer. |

## 심사 노트

App Review Information > Notes에 넣는다. 심사 노트는 언어별이 아니라 하나뿐이라 영어로만 쓴다. 한국어 번역은 `ko/metadata.md`에 있다.

Blink is a menu bar app (no Dock icon). It shows a short on-screen HUD whenever the keyboard input source changes.

IMPORTANT: The HUD only appears when the input source actually changes. If the review Mac has a single input source, nothing will appear. Please add a second one first:

1. Open System Settings > Keyboard > Input Sources > Edit…
2. Click "+", choose Korean > 2-Set Korean (any other language also works), and click Add.
3. Switch input sources with Control-Space (or the input menu in the menu bar, or the Globe/Caps Lock key if configured).
4. A HUD showing "previous → new" (for example "ABC → 2-Set Korean") appears at the center of the screen for one second.

Settings: On first launch the Settings window opens automatically. Afterwards, click the Blink icon (•→) in the menu bar and choose "Settings…" (⌘,). Settings has four panes: General, Position, Appearance, and Pointer.

New in 1.1.0 (all off by default):
• Appearance > Display Style > Abbreviation shows short labels such as "EN" instead of full names.
• General > Show HUD on Caps Lock shows "⇪ On" / "⇪ Off" when Caps Lock is pressed. It reads the Caps Lock state from NSEvent.modifierFlags; it does not monitor key presses.
• Pointer > Show Input Source Next to Pointer keeps a small badge with the current input source next to the mouse pointer. It follows mouse-move events (NSEvent global monitor for mouse events only) and NSEvent.mouseLocation.

If only one input source is installed, the Position pane shows a note explaining that the HUD will not appear.

Launch at login uses SMAppService and is off by default; it is only enabled when the user turns it on.

Blink runs in the App Sandbox, makes no network connections, collects no data, and requests no permissions (no Accessibility or Input Monitoring). It reads the current input source through the Text Input Sources API, plus the Caps Lock state and pointer location described above.
