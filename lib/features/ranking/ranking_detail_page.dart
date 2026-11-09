import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ui/glass.dart';
import '../../ui/skill_badges.dart';
import 'data/ranking_api_client.dart';
import 'install/install_commands.dart';
import 'install/install_history.dart';
import 'install/skill_installer.dart';
import 'models/ranking_models.dart';
import 'terminal/command_runner.dart';
import 'terminal/terminal_panel.dart';
import 'widgets/command_block.dart';
import 'widgets/ranking_list_tile.dart';

const _ink = Color(0xFF101828);
const _sub = Color(0xFF3A4658);
const _blue = Color(0xFF0064D1);
const _green = Color(0xFF067647);
const _amber = Color(0xFF8A5A00);
const _red = Color(0xFFB42318);
const _card = Color(0xDBFFFFFF);

/// 랭킹 스킬 하나의 상세. SKILL.md·파일·보안 점검을 보여 주고 설치를 돕는다.
///
/// "설치" 는 앱이 파일을 바로 쓰고, "직접 설치" 는 운영체제별 CLI 명령을 보여 준다.
class RankingDetailPage extends StatefulWidget {
  const RankingDetailPage({
    super.key,
    required this.item,
    required this.client,
    required this.onBack,
    this.installer,
    this.category,
    this.stars,
    this.installed = false,
    this.onInstalled,
    this.runner,
    this.history,
  });

  final SkillRankItem item;
  final RankingApiClient client;
  final VoidCallback onBack;
  final SkillInstaller? installer;
  final String? category;
  final int? stars;
  final bool installed;

  /// 앱이 설치를 마친 뒤 부른다 (내 스킬 다시 스캔 등).
  final VoidCallback? onInstalled;

  /// 터미널 패널이 쓰는 실행기. 없으면 실제 셸을 쓴다.
  final CommandRunner? runner;

  /// 설치 기록. 있으면 앱 설치와 터미널 skills 설치를 여기에 남긴다.
  final InstallHistory? history;

  @override
  State<RankingDetailPage> createState() => _RankingDetailPageState();
}

class _RankingDetailPageState extends State<RankingDetailPage> {
  late final SkillInstaller _installer = widget.installer ?? SkillInstaller();
  late final CommandRunner _runner =
      widget.runner ?? const ShellCommandRunner();
  final GlobalKey<TerminalPanelState> _terminal = GlobalKey();

  /// 터미널에서 돌고 있는 skills 설치 명령 → 그 설치 기록.
  final Map<String, InstallRecord> _cliRecords = {};

  /// 지금 컴퓨터의 운영체제. 이 운영체제의 명령만 앱에서 실행할 수 있다.
  static final InstallOs? _hostOs = Platform.isWindows
      ? InstallOs.windows
      : Platform.isMacOS
      ? InstallOs.macos
      : null;

  SkillDetail? _detail;
  String? _detailError;
  List<SkillAudit>? _audits;
  String? _auditError;

  InstallTarget _target = InstallTarget.claude;
  bool _showGuide = false;
  InstallOs _os = Platform.isMacOS ? InstallOs.macos : InstallOs.windows;

  bool _installing = false;

  /// 이 화면에서 설치 중이거나, 화면을 나갔다 오기 전에 시작한 설치가 아직 진행 중인지.
  bool get _busy =>
      _installing || (widget.history?.isRunning(widget.item.name) ?? false);

  void _onHistoryChanged() {
    if (mounted) setState(() {});
  }

  String? _installMessage;
  bool _installFailed = false;
  late bool _installed = widget.installed;

  /// 설치할 곳마다 같은 이름의 스킬 폴더가 이미 있는지 (파일 시스템 확인 결과).
  final Map<InstallTarget, bool> _present = {};

  /// 고른 설치할 곳에 이미 설치돼 있으면 설치 버튼을 숨긴다.
  /// Claude Code 는 내 스킬 스캔 결과(이름)도 함께 본다.
  bool get _alreadyInstalled =>
      (_target == InstallTarget.claude && _installed) ||
      (_present[_target] ?? false);

  Future<void> _checkPresent() async {
    for (final target in InstallTarget.values) {
      try {
        final exists = await _installer.exists(target, widget.item.slug);
        if (mounted) setState(() => _present[target] = exists);
      } on SkillInstallException {
        // 홈 폴더를 못 찾거나 이름이 폴더로 쓸 수 없으면 확인을 건너뛴다.
      }
    }
  }

  bool get _cliSupported => InstallCommands.supports(
    widget.item.source,
    widget.item.sourceType,
    widget.item.slug,
  );

  @override
  void initState() {
    super.initState();
    _loadDetail();
    _loadAudits();
    _checkPresent();
    widget.history?.addListener(_onHistoryChanged);
  }

  @override
  void dispose() {
    widget.history?.removeListener(_onHistoryChanged);
    // 상세를 닫으면 터미널 명령도 멈추므로, 진행 중이던 터미널 설치는 중지로 남긴다.
    for (final record in _cliRecords.values) {
      widget.history?.finish(record, ok: false, message: '상세 화면을 닫아 중지했습니다');
    }
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() => _detailError = null);
    try {
      final detail = await widget.client.fetchDetail(widget.item.id);
      if (mounted) setState(() => _detail = detail);
    } on RankingApiException catch (e) {
      if (mounted) setState(() => _detailError = e.message);
    }
  }

  Future<void> _loadAudits() async {
    try {
      final audits = await widget.client.fetchAudits(widget.item.id);
      if (mounted) setState(() => _audits = audits);
    } on RankingApiException catch (e) {
      if (mounted) setState(() => _auditError = e.message);
    }
  }

  Future<void> _install() async {
    final detail = _detail;
    if (detail == null || _busy) return;

    final bool exists;
    try {
      exists = await _installer.exists(_target, detail.slug);
    } on SkillInstallException catch (e) {
      _showResult(e.message, failed: true);
      return;
    }
    if (!mounted) return;
    final ok = await _confirm(detail, exists);
    if (ok != true || !mounted) return;

    setState(() {
      _installing = true;
      _installMessage = null;
    });
    final record = widget.history?.start(
      name: widget.item.name,
      source: widget.item.source,
      target: _target.label,
      method: InstallMethod.app,
    );
    try {
      final result = await _installer.install(
        detail,
        _target,
        overwrite: exists,
      );
      final skipped = result.skipped.isEmpty
          ? ''
          : ' 내용을 받지 못한 파일 ${result.skipped.length}개는 건너뛰었습니다.';
      _showResult(
        '${_target.displayPath(detail.slug)} 에 파일 ${result.written}개를 설치했습니다.$skipped',
      );
      if (record != null) {
        widget.history?.finish(
          record,
          ok: true,
          message: _target.displayPath(detail.slug),
        );
      }
      if (mounted) {
        setState(() {
          _present[_target] = true;
          if (_target == InstallTarget.claude) _installed = true;
        });
      }
      widget.onInstalled?.call();
    } on SkillInstallException catch (e) {
      if (record != null) {
        widget.history?.finish(record, ok: false, message: e.message);
      }
      _showResult(e.message, failed: true);
    }
  }

  /// 직접 설치 명령을 터미널 패널에서 실행한다.
  void _run(String command) => _terminal.currentState?.run(command);

  /// 터미널에서 skills 설치 명령을 시작하면 설치 기록에 남긴다.
  void _onCommandStarted(String command) {
    final history = widget.history;
    if (history == null || !command.contains('skills add')) return;
    final target = command.contains('-a ${InstallTarget.codex.cliAgent}')
        ? InstallTarget.codex
        : InstallTarget.claude;
    _cliRecords[command] = history.start(
      name: widget.item.name,
      source: widget.item.source,
      target: target.label,
      method: InstallMethod.cli,
    );
  }

  /// 터미널에서 skills CLI 설치가 성공하면 앱 설치와 똑같이 다시 스캔한다.
  void _onCommandFinished(String command, int exitCode) {
    final record = _cliRecords.remove(command);
    if (record != null) {
      widget.history?.finish(
        record,
        ok: exitCode == 0,
        message: exitCode == 0 ? null : '종료 코드 $exitCode',
      );
    }
    if (exitCode != 0 || !command.contains('skills add')) return;
    _checkPresent();
    if (command.contains('-a ${InstallTarget.claude.cliAgent}')) {
      setState(() => _installed = true);
    }
    widget.onInstalled?.call();
  }

  void _showResult(String message, {bool failed = false}) {
    if (!mounted) return;
    setState(() {
      _installing = false;
      _installMessage = message;
      _installFailed = failed;
    });
  }

  Future<bool?> _confirm(SkillDetail detail, bool exists) {
    final audits = _audits;
    final notPassed = audits?.where((a) => !a.passed).length ?? 0;
    final auditLine = audits == null
        ? '보안 점검 결과를 아직 받지 못했습니다.'
        : audits.isEmpty
        ? '아직 보안 점검 기록이 없는 스킬입니다.'
        : notPassed == 0
        ? '보안 점검 ${audits.length}곳 모두 통과했습니다.'
        : '보안 점검 ${audits.length}곳 중 $notPassed곳이 통과가 아닙니다. 아래 내용을 확인하세요.';
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(exists ? '이미 있는 스킬을 바꿀까요?' : '스킬을 설치할까요?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${detail.source} / ${detail.slug}'),
            const SizedBox(height: 8),
            Text('설치 위치: ${_target.displayPath(detail.slug)}'),
            Text('파일 ${detail.files.length}개'),
            const SizedBox(height: 8),
            Text(
              auditLine,
              style: TextStyle(color: notPassed > 0 ? _red : _sub),
            ),
            if (exists) ...[
              const SizedBox(height: 8),
              const Text(
                '같은 이름의 폴더를 새 파일로 바꿉니다. 그 폴더에서 고친 내용은 사라집니다.',
                style: TextStyle(color: _red),
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              '스킬은 에이전트에게 주는 지시문입니다. 믿을 수 있는 출처인지 확인하세요.',
              style: TextStyle(fontSize: 12, color: _sub),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const Key('ranking-install-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(exists ? '바꾸기' : '설치'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {const SingleActivator(LogicalKeyboardKey.escape): widget.onBack},
    child: Focus(
      autofocus: true,
      child: DefaultTextStyle(
        style: const TextStyle(color: _ink, fontSize: 14, height: 1.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                key: const PageStorageKey<String>('ranking-detail'),
                children: [
                  _installCard(),
                  if (_showGuide && !_alreadyInstalled) ...[
                    const SizedBox(height: 12),
                    _guideCard(),
                  ],
                  const SizedBox(height: 12),
                  _auditCard(),
                  const SizedBox(height: 12),
                  _contentCard(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _header() {
    final item = widget.item;
    return GlassPanel(
      radius: 30,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            GlassTap(
              key: const Key('ranking-detail-back'),
              onTap: widget.onBack,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back, size: 18, color: _ink),
                  SizedBox(width: 6),
                  Text('랭킹'),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (widget.category != null) ...[
                        const SizedBox(width: 8),
                        SkillBadge(widget.category!),
                      ],
                      if (_installed) ...[
                        const SizedBox(width: 6),
                        const SkillBadge(
                          '설치됨',
                          key: Key('ranking-detail-installed'),
                          bg: Color(0x1F067647),
                          fg: _green,
                        ),
                      ],
                    ],
                  ),
                  Text(
                    item.source,
                    style: const TextStyle(fontSize: 12, color: _sub),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '설치 ${RankingListTile.formatCount(item.installs)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (widget.stars != null)
                    Text(
                      '★ ${RankingListTile.formatCount(widget.stars!)}',
                      style: const TextStyle(fontSize: 12, color: _amber),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _cardBox({required Widget child, Key? key}) => Material(
    key: key,
    color: _card,
    borderRadius: BorderRadius.circular(22),
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );

  static Widget _title(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    ),
  );

  static Widget _choice(
    String label,
    bool selected,
    VoidCallback onTap, {
    Key? key,
  }) => Semantics(
    selected: selected,
    button: true,
    child: GlassTap(
      key: key,
      onTap: onTap,
      color: selected ? const Color(0xFFE8EEF8) : null,
      child: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    ),
  );

  Widget _installCard() {
    final ready = _detail != null && !_busy;
    return _cardBox(
      key: const Key('ranking-install-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('설치'),
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Text('설치할 곳', style: TextStyle(color: _sub)),
              ),
              for (final target in InstallTarget.values)
                _choice(
                  target.label,
                  _target == target,
                  () => setState(() => _target = target),
                  key: Key('ranking-target-${target.name}'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_alreadyInstalled && !_busy)
            Row(
              key: const Key('ranking-already-installed'),
              children: [
                const Icon(Icons.check_circle, size: 20, color: _green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_target.label}에 이미 설치되어 있습니다.',
                    style: const TextStyle(
                      color: _green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                GlassTap(
                  key: const Key('ranking-install'),
                  onTap: ready ? _install : () {},
                  color: ready ? _blue : const Color(0x660064D1),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '설치',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
                GlassTap(
                  key: const Key('ranking-direct-install'),
                  onTap: () => setState(() => _showGuide = !_showGuide),
                  color: const Color(0xFFE8EEF8),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '직접 설치',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _showGuide ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 10),
          Text(
            '설치 위치: ${_target.displayPath(widget.item.slug)}',
            style: const TextStyle(fontSize: 12, color: _sub),
          ),
          if (_target == InstallTarget.codex)
            const Text(
              '내 스킬 목록은 아직 Claude Code 폴더만 읽어서 Codex 에 설치한 스킬은 목록에 보이지 않습니다.',
              style: TextStyle(fontSize: 12, color: _sub),
            ),
          if (_detailError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '파일을 받지 못해 설치할 수 없습니다: $_detailError',
                style: const TextStyle(color: _red),
              ),
            ),
          if (_installMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _installMessage!,
                key: const Key('ranking-install-message'),
                style: TextStyle(
                  color: _installFailed ? _red : _green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _guideCard() {
    final item = widget.item;
    return _cardBox(
      key: const Key('ranking-guide-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('직접 설치'),
          if (!_cliSupported)
            const Text(
              '이 스킬은 GitHub 저장소가 아닌 곳에서 배포되어 CLI 명령을 안내하지 않습니다. 위의 설치 버튼을 써 주세요.',
              style: TextStyle(color: _sub),
            )
          else ...[
            Wrap(
              spacing: 6,
              children: [
                for (final os in InstallOs.values)
                  _choice(
                    os.label,
                    _os == os,
                    () => setState(() => _os = os),
                    key: Key('ranking-os-${os.name}'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _os == InstallOs.windows
                  ? 'PowerShell 에서 실행합니다. ${_target.label} 전역 스킬로 설치됩니다.'
                  : '터미널에서 실행합니다. ${_target.label} 전역 스킬로 설치됩니다.',
              style: const TextStyle(color: _sub),
            ),
            const SizedBox(height: 8),
            CommandBlock(
              key: Key('ranking-command-${_os.name}'),
              display: InstallCommands.display(
                _os,
                item.source,
                item.slug,
                _target,
              ),
              copyText: InstallCommands.oneLine(
                _os,
                item.source,
                item.slug,
                _target,
              ),
              onRun: _os == _hostOs
                  ? () => _run(
                      InstallCommands.oneLine(
                        _os,
                        item.source,
                        item.slug,
                        _target,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            const Text(
              'Node.js 가 없으면 먼저 설치합니다.',
              style: TextStyle(color: _sub),
            ),
            const SizedBox(height: 8),
            CommandBlock(
              key: const Key('ranking-command-node'),
              display: InstallCommands.nodeInstall(_os),
              copyText: InstallCommands.nodeInstall(_os),
              onRun: _os == _hostOs
                  ? () => _run(InstallCommands.nodeInstall(_os))
                  : null,
            ),
            const SizedBox(height: 8),
            Text(
              _os == InstallOs.windows
                  ? '복사 버튼은 한 줄짜리 명령을 복사합니다. npx 대신 npx.cmd 를 쓰는 것은 PowerShell 실행 정책에 막히지 않게 하려는 것입니다.'
                  : '복사 버튼은 한 줄짜리 명령을 복사합니다. brew 가 없으면 nodejs.org 에서 설치할 수 있습니다.',
              style: const TextStyle(fontSize: 12, color: _sub),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            _hostOs == null ? '터미널' : '터미널 · 이 컴퓨터(${_hostOs!.label})에서 실행',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            '실행 버튼은 지금 컴퓨터 운영체제의 명령에만 보입니다. 색이나 화살표 메뉴 같은 대화형 화면은 그대로 나오지 않습니다.',
            style: TextStyle(fontSize: 12, color: _sub),
          ),
          const SizedBox(height: 8),
          TerminalPanel(
            key: _terminal,
            runner: _runner,
            onStarted: _onCommandStarted,
            onFinished: _onCommandFinished,
          ),
        ],
      ),
    );
  }

  Widget _auditCard() {
    final audits = _audits;
    return _cardBox(
      key: const Key('ranking-audit-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('보안 점검'),
          if (_auditError != null)
            Text(
              '점검 결과를 불러오지 못했습니다: $_auditError',
              style: const TextStyle(color: _sub),
            )
          else if (audits == null)
            const Text('불러오는 중입니다', style: TextStyle(color: _sub))
          else if (audits.isEmpty)
            const Text('아직 보안 점검 기록이 없습니다.', style: TextStyle(color: _sub))
          else
            for (final audit in audits)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 72,
                      child: SkillBadge(
                        audit.passed ? '통과' : audit.status,
                        bg: audit.passed
                            ? const Color(0x1F067647)
                            : const Color(0x1FB42318),
                        fg: audit.passed ? _green : _red,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            audit.riskLevel == null
                                ? audit.provider
                                : '${audit.provider} · 위험도 ${audit.riskLevel}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (audit.summary.isNotEmpty)
                            Text(
                              audit.summary,
                              style: const TextStyle(fontSize: 12, color: _sub),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          const Text(
            'skills.sh 가 모은 외부 점검 결과입니다. 통과여도 내용을 직접 확인하는 것이 좋습니다.',
            style: TextStyle(fontSize: 12, color: _sub),
          ),
        ],
      ),
    );
  }

  Widget _contentCard() {
    final detail = _detail;
    return _cardBox(
      key: const Key('ranking-content-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('스킬 내용'),
          if (_detailError != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    _detailError!,
                    style: const TextStyle(color: _red),
                  ),
                ),
                TextButton(onPressed: _loadDetail, child: const Text('다시 시도')),
              ],
            )
          else if (detail == null)
            const Text('불러오는 중입니다', style: TextStyle(color: _sub))
          else ...[
            Text(
              '파일 ${detail.files.length}개',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            for (final file in detail.files)
              Text(
                file.contents == null ? '${file.path} (내용 없음)' : file.path,
                style: const TextStyle(fontSize: 12, color: _sub),
              ),
            const SizedBox(height: 16),
            const Text(
              'SKILL.md',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6FA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: SelectableText(
                detail.skillMd ?? 'SKILL.md 가 없습니다.',
                key: const Key('ranking-skill-md'),
                style: const TextStyle(
                  fontFamily: 'Consolas',
                  fontFamilyFallback: ['Menlo', 'monospace'],
                  fontSize: 13,
                  height: 1.6,
                  color: _ink,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
