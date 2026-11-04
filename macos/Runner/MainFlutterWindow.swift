import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    // 켤 때 메뉴 막대·Dock을 뺀 화면 영역을 채운다. 화면 정보가 없으면 기본 크기(1600×1000).
    let windowFrame = NSScreen.main?.visibleFrame ?? self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // 손쉬운 사용 "투명도 줄이기" 값을 Dart에 알려 준다.
    FlutterMethodChannel(
      name: "skill_gui/platform", binaryMessenger: flutterViewController.engine.binaryMessenger
    ).setMethodCallHandler { call, result in
      if call.method == "reduceTransparency" {
        result(NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}
