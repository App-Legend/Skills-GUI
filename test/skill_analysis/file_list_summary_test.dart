import 'package:flutter_test/flutter_test.dart';
import 'package:skill_gui/features/skill_analysis/file_list_summary.dart';

void main() {
  test('문서·코드는 그대로, 이미지 폴더는 묶는다', () {
    final files = [
      'SKILL.md',
      'LICENSE',
      'scripts/run.py',
      'logo.png',
      for (var i = 0; i < 932; i++) 'assets/icons/set$i/i$i.svg',
      for (var i = 0; i < 5; i++) 'assets/photos/p$i.jpg',
    ];
    expect(summarizeFileList(files), [
      'SKILL.md',
      'LICENSE',
      'scripts/run.py',
      'logo.png',
      'assets/icons/ (932개 파일)',
      'assets/photos/ (5개 파일)',
    ]);
  });

  test('파일이 많은 폴더는 문서도 묶는다', () {
    final files = [
      'SKILL.md',
      for (var i = 0; i < 20; i++) 'assets/ui/u$i.html',
      'refs/a.md',
    ];
    expect(summarizeFileList(files), [
      'SKILL.md',
      'refs/a.md',
      'assets/ui/ (20개 파일)',
    ]);
  });

  test('묶어도 많으면 뒤를 자르고 남은 수를 적는다', () {
    final out = summarizeFileList([
      for (var i = 0; i < 10; i++) 'doc$i.md',
    ], limit: 4);
    expect(out, ['doc0.md', 'doc1.md', 'doc2.md', '… 외 7개 항목']);
  });
}
