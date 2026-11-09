import 'package:flutter/foundation.dart';

import '../../scan/skill.dart';
import 'skill_analysis.dart';
import 'skill_analysis_cache.dart';
import 'skill_analysis_client.dart';
import 'skill_analysis_config.dart';

/// 목록과 상세가 함께 쓰는 분석 결과 저장소.
/// 캐시에 있으면 캐시를, 없으면 서버에 요청한다. 한 번에 [concurrency]개씩 처리한다.
class SkillAnalysisStore extends ChangeNotifier {
  SkillAnalysisStore({
    SkillAnalysisApiClient? client,
    SkillAnalysisCache? cache,
    this.concurrency = 3,
  }) : _client = client ?? SkillAnalysisConfig.createClient(),
       _cache = cache ?? SkillAnalysisConfig.createCache();

  final SkillAnalysisApiClient _client;
  final SkillAnalysisCache _cache;
  final int concurrency;

  final Map<String, SkillAnalysis> _done = {};
  final Map<String, String> _errors = {};
  final Set<String> _pending = {};
  final List<Skill> _queue = [];
  int _running = 0;
  bool _disposed = false;

  static bool canAnalyze(Skill s) =>
      s.problem == null && (s.skillMd?.trim().isNotEmpty ?? false);

  // 경로가 같아도 원문이 바뀌면 다른 항목으로 본다.
  static String _key(Skill s) => '${s.path}\n${s.skillMd.hashCode}';

  SkillAnalysis? analysisOf(Skill s) => _done[_key(s)];
  String? errorOf(Skill s) => _errors[_key(s)];
  bool isLoading(Skill s) => _pending.contains(_key(s));

  /// 아직 결과가 없는 스킬을 대기열에 넣는다. [first]면 맨 앞에 넣는다.
  void request(Iterable<Skill> skills, {bool first = false}) {
    final added = <Skill>[];
    for (final s in skills) {
      final key = _key(s);
      if (!canAnalyze(s) || _done.containsKey(key)) continue;
      if (_errors.containsKey(key)) continue;
      if (_pending.contains(key)) {
        if (first && _queue.any((q) => _key(q) == key)) {
          _queue.removeWhere((q) => _key(q) == key);
          added.add(s);
        }
        continue;
      }
      _pending.add(key);
      added.add(s);
    }
    if (added.isEmpty) return;
    first ? _queue.insertAll(0, added) : _queue.addAll(added);
    _notify();
    _pump();
  }

  /// 실패한 스킬을 다시 요청한다.
  void retry(Skill s) {
    _errors.remove(_key(s));
    request([s], first: true);
  }

  void _pump() {
    while (!_disposed && _running < concurrency && _queue.isNotEmpty) {
      _running++;
      _run(_queue.removeAt(0)).whenComplete(() {
        _running--;
        _pump();
      });
    }
  }

  Future<void> _run(Skill s) async {
    final key = _key(s);
    try {
      final cached = await _cache.load(s);
      final analysis = cached ?? await _client.analyze(s);
      if (cached == null) await _cache.save(s, analysis);
      _done[key] = analysis;
    } on SkillAnalysisApiException catch (e) {
      _errors[key] = e.message;
    } catch (_) {
      _errors[key] = '한국어 분석을 만들지 못했다.';
    }
    _pending.remove(key);
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _queue.clear();
    super.dispose();
  }
}
