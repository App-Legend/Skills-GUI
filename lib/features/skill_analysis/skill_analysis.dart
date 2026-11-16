import 'skill_categories.dart';

class SkillAnalysis {
  const SkillAnalysis({
    required this.overview,
    this.summary = '',
    this.categories = const [],
    this.whenToUse = const [],
    this.workflow = const [],
    this.requirements = const [],
    this.outputs = const [],
    this.contents = const [],
    this.cautions = const [],
    this.additionalSections = const [],
  });

  final String overview;

  /// 카드에 쓰는 한 줄 요약. 비어 있으면 overview를 쓴다.
  final String summary;

  /// skillCategories의 slug. 1~3개.
  final List<String> categories;
  final List<String> whenToUse;
  final List<String> workflow;
  final List<String> requirements;
  final List<String> outputs;
  final List<SkillAnalysisContent> contents;
  final List<String> cautions;
  final List<SkillAnalysisSection> additionalSections;

  factory SkillAnalysis.fromJson(Map<String, dynamic> json) => SkillAnalysis(
    overview: _text(json['overview']),
    summary: _text(json['summary']),
    categories: _categories(json['categories']),
    whenToUse: _texts(json['whenToUse']),
    workflow: _texts(json['workflow']),
    requirements: _texts(json['requirements']),
    outputs: _texts(json['outputs']),
    contents: _contents(json['contents']),
    cautions: _texts(json['cautions']),
    additionalSections: _sections(json['additionalSections']),
  );

  Map<String, dynamic> toJson() => {
    'overview': overview,
    'summary': summary,
    'categories': categories,
    'whenToUse': whenToUse,
    'workflow': workflow,
    'requirements': requirements,
    'outputs': outputs,
    'contents': [for (final item in contents) item.toJson()],
    'cautions': cautions,
    'additionalSections': [
      for (final item in additionalSections) item.toJson(),
    ],
  };
}

class SkillAnalysisContent {
  const SkillAnalysisContent({required this.path, required this.role});
  final String path;
  final String role;
  factory SkillAnalysisContent.fromJson(Map<String, dynamic> json) =>
      SkillAnalysisContent(
        path: _text(json['path']),
        role: _text(json['role']),
      );
  Map<String, dynamic> toJson() => {'path': path, 'role': role};
}

class SkillAnalysisSection {
  const SkillAnalysisSection({required this.title, required this.content});
  final String title;
  final String content;
  factory SkillAnalysisSection.fromJson(Map<String, dynamic> json) =>
      SkillAnalysisSection(
        title: _text(json['title']),
        content: _text(json['content']),
      );
  Map<String, dynamic> toJson() => {'title': title, 'content': content};
}

String _text(Object? value) => value is String ? value.trim() : '';

List<String> _texts(Object? value) => value is List
    ? value
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList()
    : const [];

List<String> _categories(Object? value) =>
    _texts(value)
        .where((slug) => categoryOf(slug) != null)
        .toSet()
        .take(3)
        .toList();

List<SkillAnalysisContent> _contents(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map(
        (item) =>
            SkillAnalysisContent.fromJson(Map<String, dynamic>.from(item)),
      )
      .where((item) => item.path.isNotEmpty && item.role.isNotEmpty)
      .toList();
}

List<SkillAnalysisSection> _sections(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map(
        (item) =>
            SkillAnalysisSection.fromJson(Map<String, dynamic>.from(item)),
      )
      .where((item) => item.title.isNotEmpty && item.content.isNotEmpty)
      .toList();
}
