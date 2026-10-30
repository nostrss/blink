# Blink

[한국어](README.ko.md)

Blink is a macOS menu bar app. The moment your keyboard input source changes, it shows what you switched from and to, like "ABC → 2-Set Korean", right on screen for the blink of an eye. No more typing a whole sentence in the wrong language.

![Blink HUD](docs/appstore/1.4.0/en-US/1.4.0-en-US-1.png)

[Download on the Mac App Store](https://apps.apple.com/app/blink-input-language-alert/id6823983837)

## Features

- On-screen HUD on the screen where your mouse is, above full-screen apps and on every Space. Clicks pass straight through.
- Full names or short labels like "EN" and "한", with or without the previous source.
- Nine positions or drag anywhere, display time from 0.5 to 5 seconds.
- Themes: Default (Liquid Glass on macOS Tahoe 26), Classic, High Contrast, Dracula, Gruvbox, Rosé Pine, or your own colors.
- Pointer badge: the current input source next to your pointer, always, while moving, or where you click.
- Caps Lock HUD: "⇪ On" or "⇪ Off" when you press Caps Lock.
- Statistics: input source switches and pointer use, plus typing statistics by input source and app if you turn them on.
- Follows Reduce Transparency and Reduce Motion. Launch at login, only if you want it.
- English, Korean, Japanese, Chinese (Simplified and Traditional), Russian, German, French, Spanish and Portuguese (Brazil).

See [Changelog](CHANGELOG.md) for what changed in each version.

## Privacy

Blink runs in the App Sandbox, never connects to the internet and collects nothing. Statistics stay on your Mac and can be turned off or cleared anytime. Typing statistics are off by default; when you turn them on, Blink asks for Input Monitoring permission and counts only how many keys you press, never which keys or what you type.

[Privacy Policy](https://nostrss.github.io/blink-site/privacy)

## Requirements

macOS 13 Ventura or later.

## Building from source

Requires Xcode. No third-party dependencies.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project Blink.xcodeproj -scheme Blink -configuration Debug -derivedDataPath build test
```

The Debug build is **Blink Dev** (`build/Build/Products/Debug/Blink Dev.app`, bundle ID `com.jintaek.blink.dev`, a dot on the menu bar icon). It keeps its own settings, statistics and permissions apart from the App Store version. Quit the App Store Blink before launching it, or the HUD shows twice.

## Support

Questions, bug reports or feedback: [blinkapp.support@gmail.com](mailto:blinkapp.support@gmail.com)
