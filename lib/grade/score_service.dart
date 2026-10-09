import '../core/data_cache.dart';
import 'bingo_score_service.dart';
import 'score.dart';

/// 成绩服务（数据源：Bingo 后端 `/grade`）。
///
/// 保留原类名与构造签名以兼容成绩页既有调用；内部已不再直连
/// ehall `xscjcx.do`，改由 Bingo 后端代理。
class ScoreService {
  final Object? client;
  final String baseUrl;

  ScoreService({
    this.client,
    this.baseUrl = 'https://new.bingo.yaooa.cn/api/v1',
  });

  /// 拉取成绩。[existingInfo] 仅为兼容旧调用签名，已不再用于网络请求。
  Future<ScoreResult> fetchScores(
      [StudentInfo? existingInfo, bool forceRefresh = false]) async {
    const cacheKey = 'score_result';
    if (!forceRefresh) {
      final cached = DataCache().get<ScoreResult>(cacheKey);
      if (cached != null) return cached;
    }
    final result = await BingoScoreService.instance.fetchScores();
    DataCache().set(cacheKey, result);
    return result;
  }

  /// 排名数据（`/grade/ranking`）
  Future<BingoGradeRanking> fetchRanking({String? semester}) =>
      BingoScoreService.instance.fetchRanking(semester: semester);
}

class ScoreResult {
  final StudentInfo info;
  final List<Score> scores;
  const ScoreResult({required this.info, required this.scores});
}