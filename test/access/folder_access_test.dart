import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skill_gui/access/folder_access.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('access'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('isClaudeDir: skills만 있으면 true', () async {
    Directory('${tmp.path}/skills').createSync();
    expect(await isClaudeDir(tmp), isTrue);
  });
  test('isClaudeDir: plugins만 있으면 true', () async {
    Directory('${tmp.path}/plugins').createSync();
    expect(await isClaudeDir(tmp), isTrue);
  });
  test('isClaudeDir: 둘 다 없으면 false', () async {
    File('${tmp.path}/skills').createSync(); // 파일은 폴더가 아니다
    expect(await isClaudeDir(tmp), isFalse);
  });
  test('HomeFolderAccess.grantFolder는 true', () async {
    expect(await HomeFolderAccess().grantFolder('/x'), isTrue);
    expect(await HomeFolderAccess().reduceTransparency(), isFalse);
  });
}
