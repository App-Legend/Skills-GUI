import 'package:flutter/foundation.dart';

/// 설치 한 건의 상태.
enum InstallStatus {
  running('설치 중'),
  done('완료'),
  failed('실패');

  const InstallStatus(this.label);

  final String label;
}

/// 설치 방법. 앱이 파일을 직접 쓰는지, 터미널에서 skills CLI 를 돌리는지.
enum InstallMethod {
  app('앱 설치'),
  cli('터미널 설치');

  const InstallMethod(this.label);

  final String label;
}

/// 설치 기록 한 건.
class InstallRecord {
  InstallRecord({
    required this.id,
    required this.name,
    required this.source,
    required this.target,
    required this.method,
    required this.startedAt,
  });

  final int id;
  final String name;
  final String source;

  /// 설치할 곳 이름 (Claude Code / Codex).
  final String target;
  final InstallMethod method;
  final DateTime startedAt;

  InstallStatus status = InstallStatus.running;
  DateTime? finishedAt;

  /// 끝났을 때의 한 줄 설명 (설치 위치나 실패 이유).
  String? message;
}

/// 이번 앱 실행 동안의 설치 기록. 앱을 끄면 사라진다.
///
/// 랭킹 화면 바깥(사이드바)에서도 진행 중인지 알 수 있게 앱 전체에서 하나를 같이 쓴다.
class InstallHistory extends ChangeNotifier {
  final List<InstallRecord> _records = [];
  int _nextId = 1;

  /// 오른쪽 설치 기록 패널을 열어 둘지. 설치를 시작하면 자동으로 연다.
  final ValueNotifier<bool> panelOpen = ValueNotifier(false);

  void togglePanel() => panelOpen.value = !panelOpen.value;

  /// 최근 것이 먼저.
  List<InstallRecord> get records => List.unmodifiable(_records.reversed);

  int get runningCount =>
      _records.where((r) => r.status == InstallStatus.running).length;

  bool get anyRunning => runningCount > 0;

  /// 이 스킬을 지금 설치하고 있는지.
  bool isRunning(String name) =>
      _records.any((r) => r.name == name && r.status == InstallStatus.running);

  InstallRecord start({
    required String name,
    required String source,
    required String target,
    required InstallMethod method,
    DateTime? now,
  }) {
    final record = InstallRecord(
      id: _nextId++,
      name: name,
      source: source,
      target: target,
      method: method,
      startedAt: now ?? DateTime.now(),
    );
    _records.add(record);
    panelOpen.value = true;
    notifyListeners();
    return record;
  }

  void finish(
    InstallRecord record, {
    required bool ok,
    String? message,
    DateTime? now,
  }) {
    if (record.status != InstallStatus.running) return;
    record
      ..status = ok ? InstallStatus.done : InstallStatus.failed
      ..message = message
      ..finishedAt = now ?? DateTime.now();
    notifyListeners();
  }

  /// 끝난 기록만 지운다. 진행 중인 것은 남긴다.
  void clearFinished() {
    _records.removeWhere((r) => r.status != InstallStatus.running);
    notifyListeners();
  }

  @override
  void dispose() {
    panelOpen.dispose();
    super.dispose();
  }
}
