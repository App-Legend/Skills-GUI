import 'dart:convert';
import 'dart:io';

import '../../scan/skill.dart';
import 'skill_analysis.dart';

/// 분석 형식이 바뀌면 올린다. 다른 버전의 캐시는 다시 분석한다.
/// 2: 한 줄 요약(summary)과 카테고리(categories) 추가.
const skillAnalysisCacheVersion = 2;

abstract class SkillAnalysisCache {
  Future<SkillAnalysis?> load(Skill skill);
  Future<void> save(Skill skill, SkillAnalysis analysis);
}

class FileSkillAnalysisCache implements SkillAnalysisCache {
  FileSkillAnalysisCache({this.directory});
  final Directory? directory;

  Directory get _cacheDirectory {
    if (directory case final directory?) return directory;
    final appData = Platform.environment['APPDATA'];
    final home = Platform.environment['HOME'];
    final base = Platform.isWindows
        ? appData
        : home == null
        ? null
        : '$home/Library/Application Support';
    return Directory(
      '${base ?? Directory.systemTemp.path}${Platform.pathSeparator}skill-gui${Platform.pathSeparator}skill-analysis',
    );
  }

  @override
  Future<SkillAnalysis?> load(Skill skill) async {
    try {
      final file = File(
        '${_cacheDirectory.path}${Platform.pathSeparator}${_key(skill)}.json',
      );
      if (!await file.exists()) return null;
      final value = jsonDecode(await file.readAsString());
      if (value is! Map ||
          value['version'] != skillAnalysisCacheVersion ||
          value['analysis'] is! Map) {
        return null;
      }
      final analysis = SkillAnalysis.fromJson(
        Map<String, dynamic>.from(value['analysis'] as Map),
      );
      // 카테고리가 비었으면 이전 서버가 만든 결과라 다시 분석한다.
      return analysis.overview.isEmpty || analysis.categories.isEmpty
          ? null
          : analysis;
    } on Object {
      return null;
    }
  }

  @override
  Future<void> save(Skill skill, SkillAnalysis analysis) async {
    try {
      final directory = _cacheDirectory;
      await directory.create(recursive: true);
      await File(
        '${directory.path}${Platform.pathSeparator}${_key(skill)}.json',
      ).writeAsString(
        jsonEncode({
          'version': skillAnalysisCacheVersion,
          'analysis': analysis.toJson(),
        }),
        flush: true,
      );
    } on Object {
      // 캐시 오류는 화면의 분석 결과에 영향을 주지 않는다.
    }
  }

  String _key(Skill skill) {
    final input = '${skill.path}\n${skill.skillMd}\n${skill.files.join('\n')}';
    var hash = 0xcbf29ce484222325;
    for (final byte in utf8.encode(input)) {
      hash ^= byte;
      hash = (hash * 0x100000001b3) & 0xffffffffffffffff;
    }
    return hash.toRadixString(16);
  }
}
