import 'skill_analysis_cache.dart';
import 'skill_analysis_client.dart';

class SkillAnalysisConfig {
  static const String defaultApiBase = String.fromEnvironment(
    'SKILL_ANALYSIS_API_BASE',
    defaultValue: 'https://treeplan.vercel.app',
  );
  static SkillAnalysisApiClient createClient() =>
      SkillAnalysisApiClient(defaultApiBase);
  static SkillAnalysisCache createCache() => FileSkillAnalysisCache();
}
