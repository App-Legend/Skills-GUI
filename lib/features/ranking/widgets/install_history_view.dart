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
                    icon: const PanelToggleIcon(),
                    visualDensity: VisualDensity.compact,
                    iconSize: 20,
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
    radius: 12,
    child: ListenableBuilder(
      listenable: history,
      builder: (context, _) => InkWell(
        key: const Key('install-history-open'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => history.panelOpen.value = true,
        child: Tooltip(
          message: history.anyRunning ? '설치 중 · 설치 기록 펼치기' : '설치 기록 펼치기',
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: PanelToggleIcon(busy: history.anyRunning),
          ),
        ),
      ),
    ),
  );
}

/// 오른쪽 패널을 여닫는 아이콘: 둥근 사각형 안 오른쪽에 세로 막대.
/// [busy] 면 오른쪽 위에 작은 파란 점을 붙인다 (설치 중).
class PanelToggleIcon extends StatelessWidget {
  const PanelToggleIcon({super.key, this.busy = false});

  final bool busy;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const Key('panel-toggle-icon'),
    width: 16,
    height: 20,
    child: CustomPaint(painter: _PanelIconPainter(busy: busy)),
  );
}

class _PanelIconPainter extends CustomPainter {
  const _PanelIconPainter({required this.busy});

  final bool busy;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    // 세로로 긴 사각형 (가로 12 × 세로 16).
    final box = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(3)),
      stroke,
    );
    // 패널 자리를 뜻하는 세로 막대 (오른쪽 패널이라 오른쪽에 둔다).
    final barX = box.right - 3.5;
    canvas.drawLine(
      Offset(barX, box.top + 3),
      Offset(barX, box.bottom - 3),
      stroke..strokeCap = StrokeCap.round,
    );
    if (busy) {
      canvas.drawCircle(Offset(box.right, box.top), 3, Paint()..color = _blue);
    }
  }

  @override
  bool shouldRepaint(_PanelIconPainter old) => old.busy != busy;
}
