import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    FolderAccessChannel.register(with: flutterViewController)

    super.awakeFromNib()
  }
}

// shortcut: kept in this file to avoid editing project.pbxproj; move to FolderAccessChannel.swift if it grows.
/// 사용자가 고른 폴더를 보안 범위 북마크로 저장하고 다음 실행 때 복원한다.
enum FolderAccessChannel {
  private static let bookmarksKey = "folderBookmarks"  // [경로: 북마크 Data]
  private static let claudeDirKey = "claudeDir"  // `.claude` 경로. 복원 결과 맨 앞에 온다

  static func register(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "skill_gui/folder_access", binaryMessenger: controller.engine.binaryMessenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "realHome":
        // 샌드박스에서 NSHomeDirectory()는 컨테이너 경로라서 실제 홈을 따로 구한다.
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
          result(String(cString: dir))
        } else {
          result(NSHomeDirectory())
        }
      case "saveBookmark":
        let args = call.arguments as? [String: Any]
        guard let path = args?["path"] as? String else {
          result(false)
          return
        }
        result(saveBookmark(path: path, isClaudeDir: args?["claudeDir"] as? Bool ?? false))
      case "restoreBookmarks":
        result(restoreBookmarks())
      case "reduceTransparency":
        result(NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func saveBookmark(path: String, isClaudeDir: Bool) -> Bool {
    let url = URL(fileURLWithPath: path, isDirectory: true)
    guard let data = try? url.bookmarkData(options: .withSecurityScope) else { return false }
    let defaults = UserDefaults.standard
    var bookmarks = defaults.dictionary(forKey: bookmarksKey) as? [String: Data] ?? [:]
    if isClaudeDir {
      if let old = defaults.string(forKey: claudeDirKey), old != path {
        bookmarks.removeValue(forKey: old)
      }
      defaults.set(path, forKey: claudeDirKey)
    }
    bookmarks[path] = data
    defaults.set(bookmarks, forKey: bookmarksKey)
    _ = url.startAccessingSecurityScopedResource()
    return true
  }

  /// 접근을 시작한 경로들. `.claude`가 맨 앞. 없으면 빈 목록.
  private static func restoreBookmarks() -> [String] {
    let defaults = UserDefaults.standard
    var bookmarks = defaults.dictionary(forKey: bookmarksKey) as? [String: Data] ?? [:]
    guard let claudeDir = defaults.string(forKey: claudeDirKey), bookmarks[claudeDir] != nil else {
      return []
    }
    let order = [claudeDir] + bookmarks.keys.filter { $0 != claudeDir }.sorted()
    var restored: [String] = []
    for path in order {
      var stale = false
      guard let data = bookmarks[path],
        let url = try? URL(
          resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil,
          bookmarkDataIsStale: &stale),
        url.startAccessingSecurityScopedResource()
      else {
        bookmarks.removeValue(forKey: path)
        continue
      }
      if stale, let fresh = try? url.bookmarkData(options: .withSecurityScope) {
        bookmarks[path] = fresh
      }
      restored.append(path)
    }
    defaults.set(bookmarks, forKey: bookmarksKey)
    if restored.first != claudeDir {
      defaults.removeObject(forKey: claudeDirKey)
      return []
    }
    return restored
  }
}
