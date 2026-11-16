/// 분석 서버로 보낼 파일 목록을 줄인다.
///
/// 폴더별로 `assets/icons/ (932개 파일)`처럼 한 줄로 묶는다.
/// - 파일이 [crowded]개보다 많은 폴더는 종류와 상관없이 묶는다.
/// - 나머지 폴더의 문서·코드 파일은 그대로 두고, 이미지·폰트 같은 파일만 묶는다.
/// 그래도 [limit]를 넘으면 뒤를 자른다.
List<String> summarizeFileList(
  List<String> files, {
  int limit = 300,
  int crowded = 15,
}) {
  final byDir = <String, List<String>>{};
  for (final f in files) {
    (byDir[_groupDir(f)] ??= []).add(f);
  }
  final kept = <String>[];
  final grouped = <String, List<String>>{};
  for (final f in files) {
    final dir = _groupDir(f);
    if (byDir[dir]!.length <= crowded && _isText(f)) {
      kept.add(f);
    } else {
      (grouped[dir] ??= []).add(f);
    }
  }
  final out = [
    ...kept,
    for (final MapEntry(:key, :value) in grouped.entries)
      // 하나뿐이면 묶지 않고 이름을 그대로 보낸다.
      value.length == 1
          ? value.single
          : '${key.isEmpty ? '(최상위)' : key}/ (${value.length}개 파일)',
  ];
  if (out.length <= limit) return out;
  return [...out.take(limit - 1), '… 외 ${out.length - (limit - 1)}개 항목'];
}

const _textExtensions = {
  'md', 'mdx', 'txt', 'rst', 'json', 'yaml', 'yml', 'toml', 'ini', 'cfg', //
  'py', 'js', 'mjs', 'cjs', 'ts', 'tsx', 'jsx', 'sh', 'bash', 'ps1', 'bat',
  'rb', 'go', 'rs', 'java', 'kt', 'swift', 'c', 'h', 'cpp', 'cs', 'php',
  'html', 'css', 'scss', 'sql', 'xml', 'csv', 'dart', 'lua', 'r',
};

bool _isText(String path) {
  final name = path.split('/').last;
  final dot = name.lastIndexOf('.');
  if (dot <= 0) return true; // LICENSE, Makefile 같은 확장자 없는 파일
  return _textExtensions.contains(name.substring(dot + 1).toLowerCase());
}

/// 묶음 기준 폴더. 깊은 폴더는 위 두 단계까지만 쓴다.
String _groupDir(String path) {
  final parts = path.split('/')..removeLast();
  return parts.take(2).join('/');
}
