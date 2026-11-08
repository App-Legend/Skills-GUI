import 'skill_installer.dart';

/// 직접 설치 안내를 보일 운영체제.
enum InstallOs {
  windows('Windows'),
  macos('macOS');

  const InstallOs(this.label);

  final String label;
}

/// skills CLI 설치 명령.
///
/// skills.sh 문서 기준: `npx skills add <저장소> --skill <이름> -a <에이전트> -g`.
/// `-g` 는 모든 프로젝트에서 쓰는 전역 설치다.
class InstallCommands {
  const InstallCommands._();

  /// GitHub 저장소(owner/repo) 출처만 CLI 로 안내한다.
  static bool supports(String source, String sourceType) =>
      sourceType == 'github' && RegExp(r'^[\w.-]+/[\w.-]+$').hasMatch(source);

  /// 복사용 한 줄 명령.
  static String oneLine(
    InstallOs os,
    String source,
    String slug,
    InstallTarget target,
  ) => '${_npx(os)} skills add $source --skill $slug -a ${target.cliAgent} -g';

  /// 화면에 보일 여러 줄 명령. Windows 는 PowerShell 줄잇기(`), macOS 는 \.
  static String display(
    InstallOs os,
    String source,
    String slug,
    InstallTarget target,
  ) {
    final cont = os == InstallOs.windows ? '`' : r'\';
    return [
      '${_npx(os)} skills add $source $cont',
      '  --skill $slug $cont',
      '  -a ${target.cliAgent} -g',
    ].join('\n');
  }

  /// Node.js 가 없을 때 설치하는 명령.
  static String nodeInstall(InstallOs os) => os == InstallOs.windows
      ? 'winget install OpenJS.NodeJS.LTS'
      : 'brew install node';

  // PowerShell 은 실행 정책 때문에 npx.ps1 이 막힐 수 있어 npx.cmd 를 쓴다.
  static String _npx(InstallOs os) =>
      os == InstallOs.windows ? 'npx.cmd' : 'npx';
}
