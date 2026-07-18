import '../core/http_client.dart';
import '../core/data_cache.dart';
import '../scjx2/scjx2_api_service.dart';
import 'race.dart';

/// 学科竞赛服务（API 模式）
///
/// 复用 Scjx2ApiService 处理 scjx2 通用请求逻辑（签名 + cookie + bootstrap）
class RaceService {
  final Scjx2ApiService _scjx2;

  /// RACE 模块标识
  static const String moduleId = 'race';

  /// RACE 模块的当前路由路径（用于签名头）
  static const String currentRoutePath =
      '/9001/modules/sjjx/race/stu/race/stage/list';

  RaceService({required SharedHttpClient client})
      : _scjx2 = Scjx2ApiService(client: client);

  /// 获取缓存的 JWT token
  Future<String?> getAuthToken() => _scjx2.getAuthToken(moduleId: moduleId);

  /// 清除 JWT token
  Future<void> clearAuthToken() => _scjx2.clearAuthToken(moduleId: moduleId);

  /// 是否已登录
  Future<bool> isLoggedIn() => _scjx2.isLoggedIn(moduleId: moduleId);

  /// 引导登录（zxcas → 提取 key1 → 缓存 token + cookie）
  Future<bool> bootstrapLogin() => _scjx2.bootstrapLogin(moduleId: moduleId);

  /// 拉取学科竞赛列表
  Future<RacePageResult> fetchCompetitions({
    int page = 1,
    int pageSize = 15,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'race_list_${page}_$pageSize';
    if (!forceRefresh) {
      final cached = DataCache().get<RacePageResult>(cacheKey);
      if (cached != null) return cached;
    }

    final body = <String, dynamic>{
      'currpage': page,
      'pagesize': pageSize,
    };
    final json = await _scjx2.request(
      path: '/race/race/stuRace/listStuRacePage',
      data: body,
      currentRoutePath: currentRoutePath,
      apiName: 'RACE',
      moduleId: moduleId,
    );
    final result = RacePageResult.fromJson(json);
    DataCache().set(cacheKey, result);
    return result;
  }

  /// 拉取学科竞赛详情
  Future<RaceDetail> fetchRaceDetail(String raceId) async {
    final cacheKey = 'race_detail_$raceId';
    final cached = DataCache().get<RaceDetail>(cacheKey);
    if (cached != null) return cached;

    final json = await _scjx2.request(
      path: '/race/race/stuRace/toRaceApply',
      params: {'race_id': raceId},
      currentRoutePath: currentRoutePath,
      apiName: 'RACE',
      moduleId: moduleId,
    );
    final detail = RaceDetail.fromJson(json);
    DataCache().set(cacheKey, detail);
    return detail;
  }
}
