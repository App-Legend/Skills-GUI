import 'dart:io';

import 'package:flutter/services.dart';

/// 홈 폴더의 `.claude`. 홈 경로를 모르면 null.
Directory? claudeHomeDir() {
  final home =
      Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
  return home == null ? null : Directory('$home${Platform.pathSeparator}.claude');
}

const _channel = MethodChannel('skill_gui/platform');

/// macOS "투명도 줄이기" 설정. 다른 OS나 채널 오류면 false.
Future<bool> reduceTransparency() async {
  if (!Platform.isMacOS) return false;
  try {
    return await _channel.invokeMethod<bool>('reduceTransparency') == true;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
}
