import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    // Desktop-sized first window, centred; phones' layouts still fit when narrowed.
    self.setContentSize(NSSize(width: 1280, height: 820))
    self.minSize = NSSize(width: 380, height: 600)
    self.center()
    self.title = "RomFlow"

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
