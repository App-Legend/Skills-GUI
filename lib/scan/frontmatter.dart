import 'package:yaml/yaml.dart';

/// SKILL.md 머리말에서 name·description을 읽는다. 머리말이 없거나 YAML 오류면 FormatException.
({String? name, String? description}) parseFrontmatter(String skillMd) {
  final lines = skillMd.split(RegExp(r'\r?\n'));
  if (lines.first.trim() != '---') {
    throw const FormatException('머리말이 없습니다');
  }
  final end = lines.indexWhere((l) => l.trim() == '---', 1);
  if (end < 0) throw const FormatException('머리말이 닫히지 않았습니다');
  final Object? doc;
  try {
    doc = loadYaml(lines.sublist(1, end).join('\n'));
  } on YamlException catch (e) {
    throw FormatException(e.message);
  }
  if (doc is! YamlMap) throw const FormatException('머리말이 YAML 맵이 아닙니다');
  return (
    name: doc['name']?.toString().trim(),
    description: doc['description']?.toString().trim(),
  );
}
