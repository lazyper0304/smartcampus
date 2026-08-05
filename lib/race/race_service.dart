import '../core/http_client.dart';
import '../core/data_cache.dart';
import '../scjx2/scjx2_api_service.dart';
import 'race.dart';
import 'notice.dart';

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

  /// "我的竞赛"页路由路径（用于签名头，抓包自 listMyRacePage）
  static const String myRaceRoutePath =
      '/9001/modules/sjjx/race/stu/race/myRace/list';

  /// 公示公告接口路由路径（抓包自 listNoticeStuPage，学生首页公告栏目）
  static const String noticeRoutePath = '/homeageStu';

  /// 公示公告接口基础路径（scjx2 系统级配置模块，非 RACE 子模块）
  static const String _noticeApiPath = '/config/sys/baseNotice';

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
  ///
  /// 请求失败（非登录类异常）时回退缓存，保证弱网/会话抖动时仍有数据可看。
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

    try {
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
    } catch (e) {
      // 登录类异常必须上抛（页面据此引导重登 / bootstrap）；
      // 其余异常（网络抖动、5xx、解析失败等）回退缓存兜底。
      final msg = e.toString();
      if (msg.contains('未登录 scjx2') || msg.contains('登录已过期')) rethrow;
      final cached = DataCache().get<RacePageResult>(cacheKey);
      if (cached != null) return cached;
      rethrow;
    }
  }

  /// 读取缓存的学科竞赛列表（不请求网络），供页面缓存优先渲染
  RacePageResult? cachedCompetitions({int page = 1, int pageSize = 15}) =>
      DataCache().get<RacePageResult>('race_list_${page}_$pageSize');

  /// 拉取学科竞赛详情
  Future<RaceDetail> fetchRaceDetail(String raceId) async {
    final cacheKey = 'race_detail_$raceId';
    final cached = DataCache().get<RaceDetail>(cacheKey);
    if (cached != null) return cached;

    try {
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
    } catch (e) {
      // 登录类异常上抛（页面走 bootstrap）；其余回退缓存
      final msg = e.toString();
      if (msg.contains('未登录 scjx2') || msg.contains('登录已过期')) rethrow;
      final cachedAgain = DataCache().get<RaceDetail>(cacheKey);
      if (cachedAgain != null) return cachedAgain;
      rethrow;
    }
  }

  /// 拉取"我的竞赛"列表（分页）
  ///
  /// 接口：`POST /race/race/stuRace/listMyRacePage`
  Future<MyRacePageResult> fetchMyRaces({
    int page = 1,
    int pageSize = 15,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'my_race_list_${page}_$pageSize';
    if (!forceRefresh) {
      final cached = DataCache().get<MyRacePageResult>(cacheKey);
      if (cached != null) return cached;
    }

    try {
      final body = <String, dynamic>{
        'currpage': page,
        'pagesize': pageSize,
      };
      final json = await _scjx2.request(
        path: '/race/race/stuRace/listMyRacePage',
        data: body,
        currentRoutePath: myRaceRoutePath,
        apiName: 'RACE',
        moduleId: moduleId,
      );
      final result = MyRacePageResult.fromJson(json);
      DataCache().set(cacheKey, result);
      return result;
    } catch (e) {
      // 登录类异常上抛（页面走 bootstrap）；其余回退缓存
      final msg = e.toString();
      if (msg.contains('未登录 scjx2') || msg.contains('登录已过期')) rethrow;
      final cached = DataCache().get<MyRacePageResult>(cacheKey);
      if (cached != null) return cached;
      rethrow;
    }
  }

  /// 读取缓存的"我的竞赛"列表（不请求网络），供页面缓存优先渲染
  MyRacePageResult? cachedMyRaces({int page = 1, int pageSize = 15}) =>
      DataCache().get<MyRacePageResult>('my_race_list_${page}_$pageSize');

  /// 拉取"我的竞赛"团队详情
  ///
  /// 接口：`POST /race/race/raceTeam/queryById?id=<teamId>`（空 body，id 走 query）
  Future<MyRaceDetail> fetchMyRaceDetail(String teamId) async {
    final cacheKey = 'my_race_detail_$teamId';
    final cached = DataCache().get<MyRaceDetail>(cacheKey);
    if (cached != null) return cached;

    try {
      final json = await _scjx2.request(
        path: '/race/race/raceTeam/queryById',
        params: {'id': teamId},
        currentRoutePath: myRaceRoutePath,
        apiName: 'RACE',
        moduleId: moduleId,
      );
      final detail = MyRaceDetail.fromJson(json);
      DataCache().set(cacheKey, detail);
      return detail;
    } catch (e) {
      // 登录类异常上抛（页面走 bootstrap）；其余回退缓存
      final msg = e.toString();
      if (msg.contains('未登录 scjx2') || msg.contains('登录已过期')) rethrow;
      final cachedAgain = DataCache().get<MyRaceDetail>(cacheKey);
      if (cachedAgain != null) return cachedAgain;
      rethrow;
    }
  }

  // ==================== 公示公告（baseNotice） ====================

  /// 拉取公示公告列表（分页）
  ///
  /// 接口：`POST /config/sys/baseNotice/listNoticeStuPage`
  /// 参数与抓包一致：sidx 为空 + order asc（服务端处理置顶排序）。
  Future<RaceNoticePageResult> fetchNotices({
    int page = 1,
    int pageSize = 15,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'race_notice_list_${page}_$pageSize';
    if (!forceRefresh) {
      final cached = DataCache().get<RaceNoticePageResult>(cacheKey);
      if (cached != null) return cached;
    }

    try {
      final body = <String, dynamic>{
        'currpage': page,
        'pagesize': pageSize,
        'order': 'asc',
        'sidx': '',
      };
      final json = await _scjx2.request(
        path: '$_noticeApiPath/listNoticeStuPage',
        data: body,
        currentRoutePath: noticeRoutePath,
        apiName: 'RACE',
        moduleId: moduleId,
      );
      final result = RaceNoticePageResult.fromJson(json);
      DataCache().set(cacheKey, result);
      return result;
    } catch (e) {
      // 登录类异常上抛（页面据此引导重登 / bootstrap）；
      // 其余异常（网络抖动、5xx、解析失败等）回退缓存兜底。
      final msg = e.toString();
      if (msg.contains('未登录 scjx2') || msg.contains('登录已过期')) rethrow;
      final cached = DataCache().get<RaceNoticePageResult>(cacheKey);
      if (cached != null) return cached;
      rethrow;
    }
  }

  /// 读取缓存的公示公告列表（不请求网络），供页面缓存优先渲染
  RaceNoticePageResult? cachedNotices({int page = 1, int pageSize = 15}) =>
      DataCache().get<RaceNoticePageResult>('race_notice_list_${page}_$pageSize');

  /// 拉取公示公告详情
  ///
  /// 接口：`POST /config/sys/baseNotice/getNoticeById?notice_id=<id>`
  /// （空 body，notice_id 走 query，zhxhsign 负载为 `notice_id=<id>`）
  Future<RaceNoticeDetail> fetchNoticeDetail(String noticeId) async {
    final cacheKey = 'race_notice_detail_$noticeId';
    final cached = DataCache().get<RaceNoticeDetail>(cacheKey);
    if (cached != null) return cached;

    try {
      final json = await _scjx2.request(
        path: '$_noticeApiPath/getNoticeById',
        params: {'notice_id': noticeId},
        currentRoutePath: noticeRoutePath,
        apiName: 'RACE',
        moduleId: moduleId,
      );
      final detail = RaceNoticeDetail.fromJson(json);
      DataCache().set(cacheKey, detail);
      return detail;
    } catch (e) {
      // 登录类异常上抛（页面走 bootstrap）；其余回退缓存
      final msg = e.toString();
      if (msg.contains('未登录 scjx2') || msg.contains('登录已过期')) rethrow;
      final cachedAgain = DataCache().get<RaceNoticeDetail>(cacheKey);
      if (cachedAgain != null) return cachedAgain;
      rethrow;
    }
  }

  /// 读取缓存的公示公告详情（不请求网络）
  RaceNoticeDetail? cachedNoticeDetail(String noticeId) =>
      DataCache().get<RaceNoticeDetail>('race_notice_detail_$noticeId');

  /// 下载公示公告附件（官方下载通道，带签名）
  ///
  /// 接口：`GET /config/sys/download/downNotice?id=<notice_id>&name=<URL编码文件名>`
  /// （抓包反推：zhxhsign 对**原始未编码 name** 签名——与抓包值完全匹配；
  /// URL 编码由 Scjx2ApiService.downloadBytes 内部处理）
  Future<List<int>> downloadNoticeFile({
    required String noticeId,
    required String fileName,
  }) {
    return _scjx2.downloadBytes(
      path: '/config/sys/download/downNotice',
      params: {'id': noticeId, 'name': fileName},
      currentRoutePath: noticeRoutePath,
      apiName: 'RACE',
      moduleId: moduleId,
    );
  }
}
