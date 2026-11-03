import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skill_gui/ui/access_page.dart';

void main() {
  testWidgets('null이면 안내, onGranted 안 부름', (t) async {
    var n = 0;
    await t.pumpWidget(MaterialApp(
      home: AccessPage(onPick: () async => null, onGranted: (_) => n++),
    ));
    expect(find.text('Claude Code 스킬 폴더를 허락해 주세요'), findsOneWidget);
    await t.tap(find.text('폴더 고르기'));
    await t.pump();
    expect(find.text('Claude Code 설정 폴더(.claude)를 골라 주세요'), findsOneWidget);
    expect(n, 0);
  });

  testWidgets('폴더를 고르면 onGranted', (t) async {
    Directory? got;
    await t.pumpWidget(MaterialApp(
      home: AccessPage(
          onPick: () async => Directory('/x/.claude'), onGranted: (d) => got = d),
    ));
    await t.tap(find.text('폴더 고르기'));
    await t.pump();
    expect(got?.path, '/x/.claude');
  });
}
