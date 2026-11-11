/// 스킬을 쓰는 에이전트. 폴더는 skills CLI(`npx skills add`) 문서 기준이다.
/// https://github.com/vercel-labs/skills/blob/main/docs/agents.md
enum Agent {
  claude(
    'Claude Code',
    ['.claude', 'skills'],
    ['.claude', 'skills'],
    'claude-code',
  ),
  codex('Codex', ['.agents', 'skills'], ['.agents', 'skills'], 'codex'),
  cursor('Cursor', ['.cursor', 'skills'], ['.agents', 'skills'], 'cursor'),
  copilot(
    'GitHub Copilot',
    ['.copilot', 'skills'],
    ['.agents', 'skills'],
    'github-copilot',
  ),
  gemini(
    'Gemini CLI',
    ['.gemini', 'skills'],
    ['.agents', 'skills'],
    'gemini-cli',
  ),
  opencode(
    'OpenCode',
    ['.config', 'opencode', 'skills'],
    ['.agents', 'skills'],
    'opencode',
  ),
  windsurf(
    'Windsurf',
    ['.codeium', 'windsurf', 'skills'],
    ['.windsurf', 'skills'],
    'windsurf',
  );

  const Agent(this.label, this.homeParts, this.projectParts, this.cliAgent);

  final String label;

  /// 홈 폴더 아래 전역 스킬 경로 조각.
  final List<String> homeParts;

  /// 프로젝트 폴더 아래 스킬 경로 조각.
  final List<String> projectParts;

  /// skills CLI `-a` 값.
  final String cliAgent;

  /// 화면에 보이는 전역 경로 (예: ~/.claude/skills/<이름>).
  String displayPath(String slug) => '~/${homeParts.join('/')}/$slug';

  /// 같은 프로젝트 폴더를 읽는 에이전트끼리 묶는다. `.agents/skills`는 여럿이 함께 읽는다.
  static Map<String, List<Agent>> byProjectDir() {
    final out = <String, List<Agent>>{};
    for (final a in values) {
      (out[a.projectParts.join('/')] ??= []).add(a);
    }
    return out;
  }
}
