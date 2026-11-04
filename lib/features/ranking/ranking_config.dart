/// 중계 서버 주소 설정. `--dart-define=RANKING_API_BASE=...` 로 받는다.
class RankingConfig {
  const RankingConfig._();

  static const String apiBase = String.fromEnvironment('RANKING_API_BASE');

  /// 주소가 비어 있으면 화면에서 설정 누락 오류를 보인다.
  static bool get isConfigured => apiBase.trim().isNotEmpty;

  static const String missingMessage =
      '중계 서버 주소가 설정되지 않았어요. --dart-define=RANKING_API_BASE=<주소> 로 실행해 주세요.';
}
