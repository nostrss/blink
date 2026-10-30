# 1.4.0 영어(미국) 메타데이터

App Store Connect에서 언어를 영어(미국)로 두고 붙여 넣는 문안. 섹션은 App Store Connect의 macOS 앱 버전 화면에 나오는 순서대로 적었고, 이름·부제는 '앱 정보' 화면이라 맨 끝에 둔다. 1.3.0과 달라진 곳은 스크린샷 표(4장 모두 새로 만듦), 프로모션 텍스트, 설명의 'WHAT YOU CAN DO' 포인터 배지·통계·타이핑 줄과 'PRIVACY', 이 버전의 업데이트 내용(새로 씀), 키워드(toggle → typing), 버전·빌드, 심사 노트(설정 화면 구성, 'New in 1.4.0', 이전 기능을 4,000자 안으로 줄임, 마지막 문단). 심사 노트는 4,000자 제한이다다.

## 1. 앱 미리보기 및 스크린샷

2880×1800. 실제 화면 캡처를 잘라 파란 배경(앱 아이콘 색) 위에 캡션과 함께 얹었다. "앱 미리보기"는 동영상 칸이라 쓰지 않고, 이미지는 "앱 스크린샷"에 표의 순서대로 올린다. 이 버전에서는 4장을 모두 새로 만들었다(Release 빌드, 라이트 모드, 통계는 목데이터, 메뉴바의 다른 앱 아이콘은 하늘로 덮음). 이전 버전 스크린샷은 올리지 않는다. 파일 이름의 번호는 그 버전에서 새로 만든 순서다.

| 순서 | 파일 | 장면 | 캡션 |
|---|---|---|---|
| 1 | `1.4.0-en-US-1.png` | 바탕화면 위 HUD(크게, 기본 테마) | Language switch, now visible / See the moment it changes, right on screen. |
| 2 | `1.4.0-en-US-2.png` | 통계 창(7일, 타이핑)과 메뉴의 요약 카드 | Your typing, by language / Keystrokes and speed by input source and app, counted on this Mac. |
| 3 | `1.4.0-en-US-3.png` | 설정 '포인터 배지'(배지 보기: 클릭할 때)와 바탕화면에서 클릭한 자리의 배지 | Right where you click / See the current input source right where you click. |
| 4 | `1.4.0-en-US-4.png` | 설정 '모양'(사이드바, 라이트·다크 미리보기) | Make it yours / Pick a theme, size and corners, with light and dark previews. |

## 2. 프로모션 텍스트 (170자)

Not sure your keyboard actually switched? Blink shows it on screen the moment it changes, and counts your switches and keystrokes each day. Style it your way.

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
• Pointer badge: the current input source next to your mouse pointer, always, while moving, or where you click
• Statistics: today's switches, typing and pointer use right in the menu, plus 7 and 30 days of pointer travel, clicks and scrolling
• Typing statistics: keystrokes and keys per minute by input source and by app, if you turn them on
• Caps Lock alert: "⇪ On" or "⇪ Off" when you press Caps Lock, if you want it
• Display time from 0.5 to 5 seconds
• Pick one of nine spots, or drag it anywhere
• Themes: Default (Liquid Glass on macOS Tahoe 26), Classic, High Contrast, Dracula, Gruvbox, Rosé Pine, or your own colors
• Size, corners, font weight, and an option to show only the new language
• Follows Reduce Transparency and Reduce Motion
• Launch at login, only if you want it

PRIVACY
Blink collects nothing and never connects to the internet. It reads the current input source, the Caps Lock state and where your pointer is, to draw them on screen. Statistics count input source switches, pointer movement, clicks and scrolling, and stay on your Mac. Typing statistics are off until you turn them on. They need Input Monitoring permission and count only how many keys you press, never which keys or what you type. You can turn statistics off or clear them anytime.

Available in English, Korean, Japanese, Chinese (Simplified and Traditional), Russian, German, French, Spanish, and Portuguese (Brazil).

## 4. 이 버전에서 업그레이드된 사항 (4000자)

What's new in 1.4
• Typing statistics: see how many keys you press and your keys per minute, by input source and by app. Turn it on in Settings > Statistics. It asks for Input Monitoring permission and counts keys only, never what you type.
• Today at a glance: the top of the menu now shows today's switches, typing and pointer use.
• Pointer badge: choose when it shows: Always, While Moving, or When Clicking. It now appears briefly where you click by default, and stays out of the way over the menu bar and Dock.
• Settings are grouped by feature in the sidebar: General, Input Source HUD, Pointer Badge and Statistics.

Your settings carry over. If you use the pointer badge, change when it shows in Settings > Pointer Badge > Show Badge.

## 5. 키워드 (100자)

keyboard,layout,input source,IME,switch,indicator,korean,japanese,chinese,menu bar,typo,typing

## 6. 지원 URL · 마케팅 URL · 버전 · 저작권

- 지원 URL: https://nostrss.github.io/blink-site/
- 마케팅 URL: 비워 둔다
- 버전: 1.4.0
- 저작권: 2026 jintaek woo

그 아래 '빌드'에서 1.4.0 (5)를 고른다.

## 7. 앱 심사 정보 > 메모

App Review Information > Notes에 넣는다. 심사 노트는 언어별이 아니라 하나뿐이라 영어로만 쓴다. 한국어 번역은 `ko/metadata.md`에 있다.

Blink is a menu bar app (no Dock icon). It shows a short on-screen HUD whenever the keyboard input source changes.

IMPORTANT: The HUD only appears when the input source actually changes. If the review Mac has a single input source, nothing will appear. Please add a second one first:

1. Open System Settings > Keyboard > Input Sources > Edit…
2. Click "+", choose Korean > 2-Set Korean (any other language also works), and click Add.
3. Switch input sources with Control-Space (or the input menu in the menu bar, or the Globe/Caps Lock key if configured).
4. A HUD showing "previous → new" (for example "ABC → 2-Set Korean") appears at the center of the screen for one second.

Settings: On first launch the Settings window opens automatically. Afterwards, click the Blink icon (•→) in the menu bar and choose "Settings…". The sidebar has General, Input Source HUD (Display, Position, Appearance), Pointer Badge, and Statistics.

New in 1.4.0:
• Typing Statistics (off by default, Settings > Statistics > Typing Statistics). Blink requests Input Monitoring (CGRequestListenEventAccess) only when the user turns this on; everything else works without any permission. Once allowed, Blink creates a listen-only event tap (CGEventTap, kCGSessionEventTap, kCGEventTapOptionListenOnly) for keyDown only. Per key press it reads only the autorepeat flag and timestamp, never the key code or characters, and adds one to a count with the current input source ID and the frontmost app's bundle ID. This shows keystrokes and keys per minute by input source and by app. Turning it off removes the tap immediately. Accessibility is not used.
• To try it: turn on Typing Statistics, allow Blink in System Settings > Privacy & Security > Input Monitoring (macOS offers to reopen Blink), then type in any app. The menu and "Statistics…" show the keystrokes. The "Turn On Typing Statistics" button in About Blink does the same.
• The top of the menu shows today's summary: switches, typing (when on) and pointer use.
• Pointer Badge > Show Badge: Always, While Moving, or When Clicking (default). The badge hides over the menu bar and Dock.

Earlier features:
• Statistics (1.3.0, on by default) count input source switches and pointer use. Pointer use comes from an NSEvent global monitor for mouse events only; distance uses CGDisplayScreenSize. Records are hourly totals for 90 days, then daily totals (per-app keystrokes: daily, 90 days), in Statistics.json inside the sandbox container. Settings > Statistics turns collection off and clears everything.
• About Blink opens once after an update, not on a fresh install.
• Optional, off by default: Abbreviation labels (Appearance > Display Style), the Caps Lock HUD (Display, reads NSEvent.modifierFlags only), and the pointer badge (Pointer Badge, mouse events and NSEvent.mouseLocation). On macOS 26 the Default theme uses Liquid Glass; Classic keeps the earlier look.
• Launch at login uses SMAppService, off by default.

Blink runs in the App Sandbox, makes no network connections and collects no data. The only permission it ever requests is Input Monitoring, and only when the user turns on Typing Statistics. The App Privacy answer stays "Data Not Collected" because statistics, including keystroke counts and app bundle IDs, never leave the device.

## 8. 앱 정보 화면: 이름 (30자)

Blink: Input Language Alert

## 9. 앱 정보 화면: 부제 (30자)

Language switch, now visible
