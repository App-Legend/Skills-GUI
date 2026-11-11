import 'dart:convert';
import 'dart:io';

import '../../scan/agent.dart';

/// 앱의 설치 버튼으로 설치한 스킬 하나. 업데이트 확인에 쓴다.
class AppInstallRecord {
  const AppInstallRecord({
    required this.id,
    required this.slug,
    required this.agent,
    this.hash,
  });

  /// skills.sh id (`source/slug`).
  final String id;
  final String slug;
  final Agent agent;

  /// 설치할 때 받은 skills.sh 내용 해시. 서버가 안 주면 null.
  final String? hash;

  Map<String, Object?> toJson() => {
    'id': id,
    'slug': slug,
    'agent': agent.name,
    'hash': hash,
  };

  static AppInstallRecord? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['id'], slug = j['slug'], agent = j['agent'], hash = j['hash'];
    final a = Agent.values.where((x) => x.name == agent).firstOrNull;
    if (id is! String || slug is! String || a == null) return null;
    return AppInstallRecord(
      id: id,
      slug: slug,
      agent: a,
      hash: hash is String ? hash : null,
    );
  }
}

/// 앱 설치 기록 파일. macOS `~/Library/Application Support/skill-gui/app-installs.json`,
/// Windows `%APPDATA%\skill-gui\app-installs.json` (홈 기준으로 계산해 테스트 홈과 섞이지 않는다).
class AppInstallRecords {
  AppInstallRecords(this.path);

  factory AppInstallRecords.forHome(String home) {
    final sep = Platform.pathSeparator;
    final base = Platform.isWindows
        ? '$home${sep}AppData${sep}Roaming'
        : '$home/Library/Application Support';
    return AppInstallRecords('$base${sep}skill-gui${sep}app-installs.json');
  }

  final String path;

  /// 읽지 못하거나 깨진 항목은 건너뛴다.
  Future<List<AppInstallRecord>> load() async {
    try {
      final j = jsonDecode(await File(path).readAsString());
      final list = j is Map ? j['installs'] : null;
      if (list is! List) return [];
      return [for (final e in list) ?AppInstallRecord.fromJson(e)];
    } on Object {
      return [];
    }
  }

  /// 같은 에이전트·이름의 기록은 바꾼다.
  Future<void> put(AppInstallRecord r) async {
    final all = [
      for (final x in await load())
        if (x.agent != r.agent || x.slug != r.slug) x,
      r,
    ];
    final f = File(path);
    await f.parent.create(recursive: true);
    // 임시 파일에 쓰고 옮겨서, 쓰다 멈춰도 기존 기록이 깨지지 않는다.
    final tmp = File('$path.tmp');
    await tmp.writeAsString(
      jsonEncode({
        'version': 1,
        'installs': [for (final x in all) x.toJson()],
      }),
      flush: true,
    );
    await tmp.rename(path);
  }
}
