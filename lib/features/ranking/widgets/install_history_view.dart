import 'package:flutter/material.dart';

import '../install/install_history.dart';

const _ink = Color(0xFF101828);
const _sub = Color(0xFF3A4658);
const _green = Color(0xFF067647);
const _red = Color(0xFFB42318);
const _blue = Color(0xFF0064D1);

String _time(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// 설치 기록 창을 연다. 창이 열려 있는 동안 진행 상황이 바로 바뀐다.
Future<void> showInstallHistory(BuildContext context, InstallHistory history) =>
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('설치 기록'),
        content: SizedBox(
          width: 520,
          child: InstallHistoryView(history: history),
        ),
        actions: [
          TextButton(
            key: const Key('install-history-clear'),
            onPressed: history.clearFinished,
            child: const Text('끝난 기록 지우기'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );

/// 설치 기록 목록. 최근 것이 위.
class InstallHistoryView extends StatelessWidget {
  const InstallHistoryView({super.key, required this.history});

  final InstallHistory history;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: history,
    builder: (context, _) {
      final records = history.records;
      if (records.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text(
            '아직 설치한 스킬이 없습니다. 앱을 끄면 기록도 사라집니다.',
            style: TextStyle(color: _sub),
          ),
        );
      }
      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 420),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: records.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) => _row(records[i]),
        ),
      );
    },
  );

  Widget _row(InstallRecord r) {
    final (Widget icon, Color color) = switch (r.status) {
      InstallStatus.running => (
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: _blue),
        ),
        _blue,
      ),
      InstallStatus.done => (
        const Icon(Icons.check_circle, size: 18, color: _green),
        _green,
      ),
      InstallStatus.failed => (
        const Icon(Icons.error, size: 18, color: _red),
        _red,
      ),
    };
    final when = r.finishedAt == null
        ? '${_time(r.startedAt)} 시작'
        : '${_time(r.startedAt)} ~ ${_time(r.finishedAt!)}';
    return Padding(
      key: Key('install-record-${r.id}'),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
                Text(
                  '${r.source} · ${r.target} · ${r.method.label} · $when',
                  style: const TextStyle(fontSize: 12, color: _sub),
                ),
                if (r.message != null)
                  Text(
                    r.message!,
                    style: TextStyle(fontSize: 12, color: color),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            r.status.label,
            style: TextStyle(fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}
