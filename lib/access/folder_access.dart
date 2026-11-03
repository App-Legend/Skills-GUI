import 'dart:io';

import 'macos_folder_access.dart';

/// `.claude` 폴더와 링크 대상 폴더에 읽기 권한을 얻는다.
abstract class FolderAccess {
  /// 저장된 `.claude` 권한을 복원한다(추가 허락 폴더도 함께). 없으면 null.
  Future<Directory?> restore();

  /// 폴더 선택 창. 고른 폴더가 `.claude`가 아니거나 취소하면 null.
  Future<Directory?> pickClaudeDir();

  /// 링크 대상 폴더를 추가로 허락받는다.
  Future<bool> grantFolder(String suggestedPath);

  Future<bool> reduceTransparency();
}

FolderAccess createFolderAccess() =>
    Platform.isMacOS ? MacosFolderAccess() : HomeFolderAccess();

/// `skills/` 또는 `plugins/`가 있으면 `.claude` 폴더로 본다.
Future<bool> isClaudeDir(Directory d) async =>
    await Directory('${d.path}${Platform.pathSeparator}skills').exists() ||
    await Directory('${d.path}${Platform.pathSeparator}plugins').exists();

/// 샌드박스가 없는 곳(Windows): 홈 폴더를 그대로 읽는다.
class HomeFolderAccess implements FolderAccess {
  @override
  Future<Directory?> restore() async {
    final home =
        Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
    return home == null
        ? null
        : Directory('$home${Platform.pathSeparator}.claude');
  }

  @override
  Future<Directory?> pickClaudeDir() => restore();

  @override
  Future<bool> grantFolder(String suggestedPath) async => true;

  @override
  Future<bool> reduceTransparency() async => false;
}
