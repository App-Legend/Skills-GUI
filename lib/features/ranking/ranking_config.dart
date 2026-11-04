/// 중계 서버 주소 설정.
///
/// 기본값은 팀이 같이 쓰는 배포 주소다. 다른 서버를 쓰려면
/// `--dart-define=RANKING_API_BASE=...` 로 바꾼다.
class RankingConfig {
  const RankingConfig._();

  static const String defaultApiBase = 'https://treeplan.vercel.app';

  static const String apiBase =
      String.fromEnvironment('RANKING_API_BASE', defaultValue: defaultApiBase);

  /// `--dart-define=RANKING_API_BASE=` 처럼 비워 두면 설정 누락 오류를 보인다.
  static bool get isConfigured => apiBase.trim().isNotEmpty;

  static const String missingMessage =
      '중계 서버 주소가 비어 있습니다. --dart-define=RANKING_API_BASE=<주소> 로 실행해 주세요.';
}
