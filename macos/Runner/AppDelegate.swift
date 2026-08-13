import Cocoa
import FlutterMacOS
import Network

@main
class AppDelegate: FlutterAppDelegate {
  /// Kept alive while the Local Network permission prompt may appear.
  private var localNetworkBrowser: NWBrowser?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    NSApp.activate(ignoringOtherApps: true)
    // Must run after activation so Sequoia can show the Local Network alert.
    requestLocalNetworkAuthorization()
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  /// macOS Sequoia+ Local Network privacy often blocks LAN TCP (errno 65)
  /// without listing the app in System Settings until a Bonjour browse runs.
  /// Browsing `_http._tcp` (declared in Info.plist NSBonjourServices) triggers
  /// the Allow/Don't Allow dialog and adds the app to Local Network settings.
  private func requestLocalNetworkAuthorization() {
    let descriptor = NWBrowser.Descriptor.bonjour(type: "_http._tcp", domain: nil)
    let browser = NWBrowser(for: descriptor, using: .tcp)
    browser.stateUpdateHandler = { [weak self] state in
      switch state {
      case .ready:
        self?.stopLocalNetworkBrowser()
      case .failed(let error):
        NSLog("[KDS] Local network browser failed: \(error)")
        self?.stopLocalNetworkBrowser()
      case .waiting(let error):
        // Waiting usually means the user has not granted Local Network yet.
        NSLog("[KDS] Local network browser waiting (grant Local Network in Settings if no dialog): \(error)")
      default:
        break
      }
    }
    localNetworkBrowser = browser
    browser.start(queue: .main)
    NSLog("[KDS] Started Bonjour browse to request Local Network permission")
  }

  private func stopLocalNetworkBrowser() {
    localNetworkBrowser?.cancel()
    localNetworkBrowser = nil
  }
}
