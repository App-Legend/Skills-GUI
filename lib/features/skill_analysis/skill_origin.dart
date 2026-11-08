import 'dart:convert';
import 'dart:io';

import '../../scan/skill.dart';

/// 스킬의 GitHub 주소와 설치 명령.
class SkillOrigin {
  const SkillOrigin({this.githubUrl, this.commands = const [], this.note});

  /// 모르면 null.
  final String? githubUrl;

  /// 복사해서 쓰는 명령. 순서대로 실행한다.
  final List<String> commands;

  /// 명령 위에 붙이는 안내.
  final String? note;
}

typedef SkillOriginResolver = Future<SkillOrigin> Function(Skill skill);

final _github = RegExp(
  r'^(?:https?://|git@)github\.com[/:]([^/\s]+)/([^/\s]+?)(?:\.git)?/?$',
);

/// `owner/repo`. GitHub 주소가 아니면 null.
String? githubRepoOf(String url) {
  final m = _github.firstMatch(url.trim());
  return m == null ? null : '${m[1]}/${m[2]}';
}

String _baseName(String path) =>
    path.split(RegExp(r'[/\\]')).where((p) => p.isNotEmpty).last;

String _cleanPath(String path) => path
    .replaceAll('\\', '/')
    .split('/')
    .where((p) => p.isNotEmpty && p != '.')
    .join('/');

Future<Map<String, dynamic>?> _readJson(String path) async {
  try {
    final v = jsonDecode(await File(path).readAsString());
    return v is Map<String, dynamic> ? v : null;
  } on Object {
    return null;
  }
}

/// `npx skills add -g`가 남기는 설치 기록(`~/.agents/.skill-lock.json`)에서 출처를 찾는다.
/// 기록이 없거나 GitHub 출처가 아니면 null.
Future<SkillOrigin?> _fromSkillsLock(
  Skill s,
  String folder,
  Directory? claudeDir,
) async {
  if (claudeDir == null) return null;
  final sep = Platform.pathSeparator;
  final lock = await _readJson(
    '${claudeDir.parent.path}$sep.agents$sep.skill-lock.json',
  );
  final skills = lock?['skills'];
  if (skills is! Map) return null;
  final key = skills.containsKey(folder) ? folder : s.name;
  final entry = skills[key];
  if (entry is! Map) return null;
  final source = entry['source'];
  final url = entry['sourceUrl'];
  final repo = entry['sourceType'] == 'github' && source is String
      ? source
      : url is String
      ? githubRepoOf(url)
      : null;
  if (repo == null || source is! String) return null;
  final skillPath = entry['skillPath'];
  final dir = skillPath is String && skillPath.contains('/')
      ? _cleanPath(skillPath.substring(0, skillPath.lastIndexOf('/')))
      : '';
  return SkillOrigin(
    githubUrl:
        'https://github.com/$repo/tree/HEAD${dir.isEmpty ? '' : '/$dir'}',
    commands: [
      'npx skills add $source --skill ${key.contains(' ') ? '"$key"' : key} '
          '-g -a claude-code',
    ],
  );
}

/// 출처를 찾는다. 예외를 밖으로 던지지 않는다.
Future<SkillOrigin> resolveSkillOrigin(Skill s, Directory? claudeDir) async {
  if (s.source == SkillSource.synced) return const SkillOrigin();
  if (s.source != SkillSource.plugin || s.plugin == null) {
    final folder = _baseName(s.path);
    if (await _fromSkillsLock(s, folder, claudeDir) case final origin?) {
      return origin;
    }
    return SkillOrigin(
      note: '출처 정보가 없는 스킬입니다. 스킬 폴더를 아래 위치에 복사하면 설치됩니다.',
      commands: [
        Platform.isWindows
            ? '%USERPROFILE%\\.claude\\skills\\$folder'
            : '~/.claude/skills/$folder',
      ],
    );
  }
  final id = s.plugin!;
  final at = id.lastIndexOf('@');
  final pluginName = at < 0 ? id : id.substring(0, at);
  final market = at < 0 ? '' : id.substring(at + 1);
  final install = '/plugin install $id';
  if (claudeDir == null || market.isEmpty) {
    return SkillOrigin(commands: [install]);
  }

  final sep = Platform.pathSeparator;
  final known = await _readJson(
    '${claudeDir.path}${sep}plugins${sep}known_marketplaces.json',
  );
  final entry = known?[market];
  if (entry is! Map) return SkillOrigin(commands: [install]);

  // 마켓 추가에 쓰는 값과 마켓 저장소.
  String? addArg;
  String? marketRepo;
  final source = entry['source'];
  if (source is Map) {
    final repo = source['repo'];
    final url = source['url'];
    final path = source['path'];
    if (repo is String) {
      addArg = repo;
      marketRepo = repo;
    } else if (url is String) {
      addArg = url;
      marketRepo = githubRepoOf(url);
    } else if (path is String) {
      addArg = path;
    }
  }
  final commands = [
    if (addArg != null) '/plugin marketplace add $addArg',
    install,
  ];

  // 마켓 안의 플러그인 위치.
  final location = entry['installLocation'];
  final manifest = location is String
      ? await _readJson('$location$sep.claude-plugin${sep}marketplace.json')
      : null;
  final plugins = manifest?['plugins'];
  Map? plugin;
  if (plugins is List) {
    for (final p in plugins) {
      if (p is Map && p['name'] == pluginName) plugin = p;
    }
  }
  final skillPath = 'skills/${_baseName(s.path)}';
  String? url;
  final ps = plugin?['source'];
  if (ps is String && marketRepo != null) {
    final dir = _cleanPath(ps);
    url =
        'https://github.com/$marketRepo/tree/HEAD/'
        '${dir.isEmpty ? '' : '$dir/'}$skillPath';
  } else if (ps is Map) {
    final repo = ps['repo'] is String
        ? ps['repo'] as String
        : ps['url'] is String
        ? githubRepoOf(ps['url'] as String)
        : null;
    if (repo != null) {
      final ref = ps['ref'] is String ? ps['ref'] as String : 'HEAD';
      final dir = ps['path'] is String ? _cleanPath(ps['path'] as String) : '';
      url =
          'https://github.com/$repo/tree/$ref/'
          '${dir.isEmpty ? '' : '$dir/'}$skillPath';
    }
  }
  return SkillOrigin(githubUrl: url, commands: commands);
}

/// 기본 브라우저로 https 주소를 연다. 성공하면 true.
Future<bool> openExternalUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https') return false;
  try {
    final r = Platform.isWindows
        ? await Process.run('rundll32', ['url.dll,FileProtocolHandler', url])
        : await Process.run(Platform.isMacOS ? 'open' : 'xdg-open', [url]);
    return r.exitCode == 0;
  } on Object {
    return false;
  }
}
