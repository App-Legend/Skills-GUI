import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';

import 'folder_access.dart';

/// 샌드박스 macOS: 사용자가 고른 폴더를 보안 범위 북마크로 저장·복원한다.
/// 채널 오류는 모두 "권한 없음"으로 본다.
class MacosFolderAccess implements FolderAccess {
  static const _channel = MethodChannel('skill_gui/folder_access');

  @override
  Future<Directory?> restore() async {
    try {
      final paths =
          await _channel.invokeListMethod<String>('restoreBookmarks') ?? [];
      return paths.isEmpty ? null : Directory(paths.first);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<Directory?> pickClaudeDir() async {
    try {
      final home = await _channel.invokeMethod<String>('realHome');
      final path = await getDirectoryPath(
        initialDirectory: home == null ? null : '$home/.claude',
        confirmButtonText: '허락',
      );
      if (path == null || !await isClaudeDir(Directory(path))) return null;
      final saved = await _channel.invokeMethod<bool>('saveBookmark', {
        'path': path,
        'claudeDir': true,
      });
      return saved == true ? Directory(path) : null;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<bool> grantFolder(String suggestedPath) async {
    try {
      final path = await getDirectoryPath(
        initialDirectory: suggestedPath,
        confirmButtonText: '허락',
      );
      if (path == null) return false;
      return await _channel.invokeMethod<bool>('saveBookmark', {
            'path': path,
          }) ==
          true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> reduceTransparency() async {
    try {
      return await _channel.invokeMethod<bool>('reduceTransparency') == true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
