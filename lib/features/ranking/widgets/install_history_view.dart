import 'package:flutter/material.dart';

import '../../../ui/glass.dart';
import '../install/install_history.dart';

const _ink = Color(0xFF101828);
const _sub = Color(0xFF3A4658);
const _green = Color(0xFF067647);
const _red = Color(0xFFB42318);
const _blue = Color(0xFF0064D1);

String _time(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// 오른쪽 사이드바의 설치 기록 패널. 왼쪽 사이드바와 같은 유리 패널 모양이다.
class InstallHistoryPanel extends StatelessWidget {
  const InstallHistoryPanel({super.key, required this.history});

  final InstallHistory history;

  @override
  Widget build(BuildContext context) => GlassPanel(
    key: const Key('install-history-panel'),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
      child: ListenableBuilder(
        listenable: history,
        builder: (context, _) {
          final running = history.runningCount;
          final hasFinished = history.records.length > running;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '설치 기록',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('install-history-close'),
                    tooltip: '설치 기록 접기',
                    icon: const Icon(
                      Icons.keyboard_double_arrow_right_rounded,
                      size: 20,
                      color: _sub,
                    ),
                    onPressed: () => history.panelOpen.value = false,
                  ),
                ],
              ),
              Text(
                running > 0 ? '설치 중 $running개' : '이번 실행 동안의 설치',
                style: TextStyle(
                  fontSize: 12,
                  color: running > 0 ? _blue : _sub,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: InstallHistoryView(history: history)),
              if (hasFinished)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    key: const Key('install-history-clear'),
                    onPressed: history.clearFinished,
                    style: TextButton.styleFrom(foregroundColor: _sub),
                    child: const Text('끝난 기록 지우기'),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

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
          padding: EdgeInsets.only(top: 16, right: 8),
          child: Text(
            '아직 설치한 스킬이 없습니다. 앱을 끄면 기록도 사라집니다.',
            style: TextStyle(fontSize: 13, color: _sub),
          ),
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.only(right: 8),
        itemCount: records.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) => _row(records[i]),
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
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _ink,
                        ),
                      ),
                    ),
                    Text(
                      r.status.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${r.target} · ${r.method.label} · $when',
                  style: const TextStyle(fontSize: 12, color: _sub),
                ),
                Text(
                  r.source,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
        ],
      ),
    );
  }
}

/// 설치 기록이 접혀 있을 때 오른쪽 끝에 보이는 좁은 탭. 누르면 펼친다.
class InstallHistoryRail extends StatelessWidget {
  const InstallHistoryRail({super.key, required this.history});

  final InstallHistory history;

  @override
  Widget build(BuildContext context) => GlassPanel(
    key: const Key('install-history-rail'),
    radius: 22,
    child: ListenableBuilder(
      listenable: history,
      builder: (context, _) {
        final running = history.runningCount;
        return InkWell(
          key: const Key('install-history-open'),
          borderRadius: BorderRadius.circular(22),
          onTap: () => history.panelOpen.value = true,
          child: Tooltip(
            message: '설치 기록 펼치기',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.keyboard_double_arrow_left_rounded,
                    size: 20,
                    color: _sub,
                  ),
                  const SizedBox(height: 10),
                  if (running > 0) ...[
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _blue,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$running',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _blue,
                      ),
                    ),
                  ] else
                    const Icon(Icons.history_rounded, size: 20, color: _sub),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
