import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skill_gui/features/ranking/install/install_commands.dart';
import 'package:skill_gui/features/ranking/install/skill_installer.dart';
import 'package:skill_gui/features/ranking/models/ranking_models.dart';

// 테스트용 가짜 스킬. 실제 skills.sh 데이터가 아니다.
SkillDetail _detail(List<SkillFile> files, {String slug = 'fake-skill'}) =>
    SkillDetail(
      id: 'fake/repo/$slug',
      source: 'fake/repo',
      slug: slug,
      installs: 1,
      files: files,
    );

const _md = SkillFile(path: 'SKILL.md', contents: '---\nname: fake\n---\n본문');

void main() {
  late Directory home;
  late SkillInstaller installer;
  final sep = Platform.pathSeparator;

  setUp(() {
    home = Directory.systemTemp.createTempSync('installer-test');
    installer = SkillInstaller(home: home.path);
  });
  tearDown(() => home.deleteSync(recursive: true));

  String read(List<String> parts) =>
      File([home.path, ...parts].join(sep)).readAsStringSync();

  test('Claude Code 폴더에 하위 폴더까지 파일을 쓴다', () async {
    final result = await installer.install(
      _detail([_md, const SkillFile(path: 'docs/guide.md', contents: '안내')]),
      InstallTarget.claude,
    );
    expect(result.written, 2);
    expect(result.skipped, isEmpty);
    expect(
      read(['.claude', 'skills', 'fake-skill', 'SKILL.md']),
      contains('본문'),
    );
    expect(read(['.claude', 'skills', 'fake-skill', 'docs', 'guide.md']), '안내');
  });

  test('Codex 는 ~/.agents/skills 에 쓴다', () async {
    await installer.install(_detail([_md]), InstallTarget.codex);
    expect(
      read(['.agents', 'skills', 'fake-skill', 'SKILL.md']),
      contains('본문'),
    );
  });

  test('내용이 없는 파일은 건너뛰고 알려 준다', () async {
    final result = await installer.install(
      _detail([_md, const SkillFile(path: 'logo.png', contents: null)]),
      InstallTarget.claude,
    );
    expect(result.skipped, ['logo.png']);
    expect(
      File([home.path, '.claude', 'skills', 'fake-skill', 'logo.png'].join(sep))
          .existsSync(),
      isFalse,
    );
  });

  test('이미 있으면 overwrite 없이는 멈추고, overwrite 면 통째로 바꾼다', () async {
    await installer.install(
      _detail([_md, const SkillFile(path: 'old.md', contents: '옛')]),
      InstallTarget.claude,
    );
    expect(await installer.exists(InstallTarget.claude, 'fake-skill'), isTrue);

    await expectLater(
      installer.install(_detail([_md]), InstallTarget.claude),
      throwsA(isA<SkillInstallException>()),
    );

    await installer.install(
      _detail([const SkillFile(path: 'SKILL.md', contents: '새 본문')]),
      InstallTarget.claude,
      overwrite: true,
    );
    expect(read(['.claude', 'skills', 'fake-skill', 'SKILL.md']), '새 본문');
    expect(
      File([home.path, '.claude', 'skills', 'fake-skill', 'old.md'].join(sep))
          .existsSync(),
      isFalse,
    );
    // 임시·백업 폴더가 남지 않는다.
    final left = Directory([home.path, '.claude', 'skills'].join(sep))
        .listSync()
        .map((e) => e.uri.pathSegments.where((s) => s.isNotEmpty).last);
    expect(left, ['fake-skill']);
  });

  test('폴더 밖으로 나가는 경로는 아무것도 쓰지 않고 거절한다', () async {
    for (final bad in ['../evil.md', '/etc/x', 'a/../../x', r'C:\x.md']) {
      await expectLater(
        installer.install(
          _detail([_md, SkillFile(path: bad, contents: 'x')]),
          InstallTarget.claude,
        ),
        throwsA(isA<SkillInstallException>()),
        reason: bad,
      );
    }
    expect(Directory([home.path, '.claude'].join(sep)).existsSync(), isFalse);
  });

  test('폴더 이름으로 못 쓰는 slug 는 거절한다', () {
    expect(
      () => installer.targetPath(InstallTarget.claude, '../x'),
      throwsA(isA<SkillInstallException>()),
    );
  });

  test('SKILL.md 가 없으면 설치하지 않는다', () async {
    await expectLater(
      installer.install(
        _detail([const SkillFile(path: 'README.md', contents: 'x')]),
        InstallTarget.claude,
      ),
      throwsA(isA<SkillInstallException>()),
    );
  });

  group('InstallCommands', () {
    test('운영체제별 명령과 줄잇기 기호', () {
      expect(
        InstallCommands.oneLine(
          InstallOs.macos,
          'anthropics/skills',
          'frontend-design',
          InstallTarget.claude,
        ),
        'npx skills add anthropics/skills --skill frontend-design -a claude-code -g',
      );
      expect(
        InstallCommands.oneLine(
          InstallOs.windows,
          'anthropics/skills',
          'frontend-design',
          InstallTarget.codex,
        ),
        'npx.cmd skills add anthropics/skills --skill frontend-design -a codex -g',
      );
      expect(
        InstallCommands.display(
          InstallOs.windows,
          'a/b',
          'c',
          InstallTarget.claude,
        ),
        'npx.cmd skills add a/b `\n  --skill c `\n  -a claude-code -g',
      );
      expect(
        InstallCommands.display(
          InstallOs.macos,
          'a/b',
          'c',
          InstallTarget.claude,
        ),
        'npx skills add a/b \\\n  --skill c \\\n  -a claude-code -g',
      );
    });

    test('GitHub 저장소 출처만 CLI 를 안내한다', () {
      expect(
        InstallCommands.supports('anthropics/skills', 'github', 'pdf'),
        isTrue,
      );
      expect(
        InstallCommands.supports('open.feishu.cn', 'well-known', 'pdf'),
        isFalse,
      );
    });

    test('셸에 끼어들 수 있는 스킬 이름은 CLI 를 안내하지 않는다', () {
      expect(InstallCommands.supports('a/b', 'github', 'x; echo hi'), isFalse);
      expect(InstallCommands.supports('a/b', 'github', r'x$(id)'), isFalse);
    });
  });
}
