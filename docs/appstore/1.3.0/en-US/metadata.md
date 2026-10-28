# 1.3.0 영어(미국) 메타데이터

App Store Connect에서 언어를 영어(미국)로 두고 붙여 넣는 문안. 섹션은 App Store Connect의 macOS 앱 버전 화면에 나오는 순서대로 적었고, 이름·부제는 '앱 정보' 화면이라 맨 끝에 둔다. 1.2.0과 달라진 곳은 스크린샷 표(통계 1장 추가), 프로모션 텍스트, 설명의 'WHAT YOU CAN DO' 통계 줄과 'PRIVACY', 이 버전의 업데이트 내용(새로 씀), 심사 노트(설정 화면 수, 'New in 1.3.0', 마지막 문단)다.

## 1. 앱 미리보기 및 스크린샷

2880×1800. 실제 화면 캡처를 잘라 파란 배경(앱 아이콘 색) 위에 캡션과 함께 얹었다. "앱 미리보기"는 동영상 칸이라 쓰지 않고, 이미지는 "앱 스크린샷"에 표의 순서대로 올린다. 이 버전에서 새로 만든 스크린샷은 2(통계) 한 장이다. 1·3·4는 1.0.0, 5는 1.1.0 것을 그대로 쓴다(1의 HUD는 클래식·macOS 13–15의 기본 모양과 같다). 파일 이름의 번호는 그 버전에서 새로 만든 순서다.

| 순서 | 파일 | 장면 | 캡션 |
|---|---|---|---|
| 1 | `../../1.0.0/en-US/1.0.0-en-US-1.png` | 바탕화면 위 HUD(크게) | Language switch, now visible / See the moment it changes, right on screen. |
| 2 | `1.3.0-en-US-1.png` | 메뉴의 통계 카드와 통계 창(7일) | Your day in numbers / Count input switches, clicks and pointer travel, right on this Mac. |
| 3 | `../../1.0.0/en-US/1.0.0-en-US-2.png` | 설정 '위치' | Put it anywhere / Pick one of nine spots, or drag the HUD where you want it. |
| 4 | `../../1.0.0/en-US/1.0.0-en-US-3.png` | 설정 '모양' | Make it yours / Change size, corners and font weight, with light and dark previews. |
| 5 | `../../1.1.0/en-US/1.1.0-en-US-1.png` | 설정 '포인터'와 바탕화면에서 포인터를 따라가는 배지 | Right by your pointer / Keep the current input source next to your mouse pointer. |

## 2. 프로모션 텍스트 (170자)

Not sure your keyboard actually switched? Blink shows it on screen the moment it changes, and counts how often you switch each day. Style it the way you like.

## 3. 설명 (4000자)

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
• Statistics: today's input source switches right in the menu, plus pointer travel, clicks and scrolling over 7 or 30 days
• Caps Lock alert: "⇪ On" or "⇪ Off" when you press Caps Lock, if you want it
• Display time from 0.5 to 5 seconds
• Pick one of nine spots, or drag it anywhere
• Themes: Default (Liquid Glass on macOS Tahoe 26), Classic, High Contrast, Dracula, Gruvbox, Rosé Pine, or your own colors
• Size, corners, font weight, and an option to show only the new language
• Follows Reduce Transparency and Reduce Motion
• Launch at login, only if you want it

PRIVACY
Blink collects nothing, never connects to the internet, and needs no special permissions. It reads the current input source, the Caps Lock state and where your pointer is, to draw them on screen. Statistics count input source switches, pointer movement, clicks and scrolling, never what you type, and stay on your Mac. You can turn them off or clear them anytime.

Available in English, Korean, Japanese, Chinese (Simplified and Traditional), Russian, German, French, Spanish, and Portuguese (Brazil).

## 4. 이 버전에서 업그레이드된 사항 (4000자)

What's new in 1.3
• Statistics: see how many times you switched input sources today at the top of the menu. Choose Statistics… for 7 and 30 days, with pointer travel, average speed, clicks and scrolling.
• Everything stays on your Mac. Blink counts switches and pointer use only, never what you type. Turn it off or clear it in Settings > Statistics.
• Tidier Settings: options are grouped into boxes, like System Settings.
• About Blink now shows what's new, and opens once after an update.

Your settings carry over as they are.

## 5. 키워드 (100자)

keyboard,layout,input source,IME,switch,indicator,korean,japanese,chinese,menu bar,typo,toggle

## 6. 지원 URL · 마케팅 URL · 버전 · 저작권

- 지원 URL: https://nostrss.github.io/blink-site/
- 마케팅 URL: 비워 둔다
- 버전: 1.3.0
- 저작권: 2026 jintaek woo

그 아래 '빌드'에서 1.3.0 (4)를 고른다.

## 7. 앱 심사 정보 > 메모

App Review Information > Notes에 넣는다. 심사 노트는 언어별이 아니라 하나뿐이라 영어로만 쓴다. 한국어 번역은 `ko/metadata.md`에 있다.

Blink is a menu bar app (no Dock icon). It shows a short on-screen HUD whenever the keyboard input source changes.

IMPORTANT: The HUD only appears when the input source actually changes. If the review Mac has a single input source, nothing will appear. Please add a second one first:

1. Open System Settings > Keyboard > Input Sources > Edit…
2. Click "+", choose Korean > 2-Set Korean (any other language also works), and click Add.
3. Switch input sources with Control-Space (or the input menu in the menu bar, or the Globe/Caps Lock key if configured).
4. A HUD showing "previous → new" (for example "ABC → 2-Set Korean") appears at the center of the screen for one second.

Settings: On first launch the Settings window opens automatically. Afterwards, click the Blink icon (•→) in the menu bar and choose "Settings…" (⌘,). Settings has five panes: General, Position, Appearance, Pointer, and Statistics.

New in 1.3.0:
• Statistics (on by default): Blink counts input source switches and pointer usage on this Mac. The top of the menu shows today's switches with an hourly bar chart, and "Statistics…" opens a window with Today, 7 Days and 30 Days. Pointer usage comes from an NSEvent global monitor for mouse events only (mouse moved/dragged, left and right mouse down, scroll wheel); keyboard events are not monitored and no content is recorded. Distance is converted to millimeters with CGDisplayScreenSize.
• Counts are kept as hourly totals for 90 days and daily totals after that, in Application Support/Statistics.json inside the app's sandbox container. Nothing leaves the Mac. Settings > Statistics turns collection off and clears all records (with a confirmation sheet).
• About Blink lists what's new in this version. On the first launch after an update it opens once by itself; it does not open on a fresh install.

From 1.2.0:
• On macOS 26 (Tahoe) and later, the Default theme draws the HUD, the Settings previews and the pointer badge with Liquid Glass (NSGlassEffectView). Appearance > Theme > Classic keeps the earlier look and is only listed on macOS 26 and later.

Optional features from 1.1.0 (all off by default):
• Appearance > Display Style > Abbreviation shows short labels such as "EN" instead of full names.
• General > Show HUD on Caps Lock shows "⇪ On" / "⇪ Off" when Caps Lock is pressed. It reads the Caps Lock state from NSEvent.modifierFlags; it does not monitor key presses.
• Pointer > Show Input Source Next to Pointer keeps a small badge with the current input source next to the mouse pointer. It follows mouse-move events (NSEvent global monitor for mouse events only) and NSEvent.mouseLocation.

If only one input source is installed, the Position pane shows a note explaining that the HUD will not appear.

Launch at login uses SMAppService and is off by default; it is only enabled when the user turns it on.

Blink runs in the App Sandbox, makes no network connections, collects no data, and requests no permissions (no Accessibility or Input Monitoring). It reads the current input source through the Text Input Sources API, plus the Caps Lock state, pointer location and mouse events described above. The App Privacy answer stays "Data Not Collected" because statistics never leave the device.

## 8. 앱 정보 화면: 이름 (30자)

Blink: Input Language Alert

## 9. 앱 정보 화면: 부제 (30자)

Language switch, now visible
