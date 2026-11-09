import 'package:flutter/foundation.dart';

import '../../scan/skill.dart';
import '../ranking/models/ranking_models.dart';
import 'skill_analysis.dart';
import 'skill_analysis_store.dart';

/// 랭킹 스킬의 한국어 분석. skills.sh에서 SKILL.md를 받아 [SkillAnalysisStore]에 넘긴다.
/// 받은 내용은 앱을 끌 때까지 기억하고, 분석 결과는 내 스킬과 같은 파일 캐시에 남는다.
class RankingAnalysis extends ChangeNotifier {
  RankingAnalysis({
    required this.store,
    required this.fetchDetail,
    this.concurrency = 3,
  }) {
    store.addListener(_notify);
  }

  final SkillAnalysisStore store;

  /// skills.sh에서 스킬 내용(SKILL.md·파일)을 받는다.
  final Future<SkillDetail> Function(String id) fetchDetail;
  final int concurrency;

  final Map<String, Skill> _skills = {};
  final Map<String, String> _fetchErrors = {};
  final Set<String> _fetching = {};
  final List<SkillRankItem> _queue = [];
  int _running = 0;
  bool _disposed = false;

  /// 분석에 넘기는 스킬. 경로는 skills.sh 주소로 둬 내 스킬과 겹치지 않게 한다.
  static Skill skillOf(SkillRankItem item, SkillDetail detail) => Skill(
    name: item.name,
    source: SkillSource.global,
    path: 'skills.sh/${item.id}',
    skillMd: detail.skillMd,
    files: [for (final f in detail.files) f.path],
  );

  SkillAnalysis? analysisOf(SkillRankItem item) {
    final s = _skills[item.id];
    return s == null ? null : store.analysisOf(s);
  }

  String? errorOf(SkillRankItem item) {
    if (_fetchErrors[item.id] case final e?) return e;
    final s = _skills[item.id];
    if (s == null) return null;
    if (!SkillAnalysisStore.canAnalyze(s)) return 'SKILL.md가 없어 분석하지 못했다.';
    return store.errorOf(s);
  }

  bool isLoading(SkillRankItem item) {
    if (_fetching.contains(item.id)) return true;
    final s = _skills[item.id];
    return s != null && store.isLoading(s);
  }

  /// 목록에 보인 스킬을 분석한다. 이미 받았거나 받는 중이면 넘어간다.
  void request(SkillRankItem item, {bool first = false}) {
    if (_skills[item.id] case final s?) {
      store.request([s], first: first);
      return;
    }
    if (_fetchErrors.containsKey(item.id)) return;
    if (_fetching.contains(item.id)) {
      if (first && _queue.any((q) => q.id == item.id)) {
        _queue.removeWhere((q) => q.id == item.id);
        _queue.insert(0, item);
      }
      return;
    }
    _fetching.add(item.id);
    first ? _queue.insert(0, item) : _queue.add(item);
    _notify();
    _pump();
  }

  /// 상세 화면이 이미 받은 내용을 그대로 쓴다.
  void useDetail(SkillRankItem item, SkillDetail detail) {
    _fetchErrors.remove(item.id);
    final s = _skills[item.id] = skillOf(item, detail);
    store.request([s], first: true);
  }

  void retry(SkillRankItem item) {
    _fetchErrors.remove(item.id);
    if (_skills[item.id] case final s?) {
      store.retry(s);
    } else {
      request(item, first: true);
    }
  }

  void _pump() {
    while (!_disposed && _running < concurrency && _queue.isNotEmpty) {
      _running++;
      _fetch(_queue.removeAt(0)).whenComplete(() {
        _running--;
        _pump();
      });
    }
  }

  Future<void> _fetch(SkillRankItem item) async {
    try {
      final detail = await fetchDetail(item.id);
      if (_disposed) return;
      final s = _skills[item.id] = skillOf(item, detail);
      store.request([s]);
    } catch (_) {
      _fetchErrors[item.id] = '스킬 내용을 불러오지 못했다.';
    }
    _fetching.remove(item.id);
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _queue.clear();
    store.removeListener(_notify);
    super.dispose();
  }
}
