import AppKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    // MainMenu nib이 없으므로 delegate를 직접 연결한다.
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
    }
}
