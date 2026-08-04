import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()

    // Flutter's `open` often returns 1 on macOS 26 even when launch succeeds.
    // Force the window forward so the UI is visible after `flutter run`.
    makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }
}
