import '../core/http_client.dart';
import '../core/data_cache.dart';
import '../scjx2/scjx2_api_service.dart';
import 'srtp.dart';

/// 大学生创新创业训练计划（SRTP）服务（API 模式）
///
/// 复用 Scjx2ApiService 处理 scjx2 通用请求逻辑（签名 + cookie + bootstrap）
class SrtpService {
  final Scjx2ApiService _scjx2;

  /// SRTP 模块标识
  static const String moduleId = 'srtp';

  /// SRTP 模块的当前路由路径（用于签名头，抓包自 joinProject 页）
  static const String currentRoutePath = '/12001/modules/srtp/stu/joinProject';

  /// "我申请的项目"页路由路径（抓包自 listProjectProgressPage）
  static const String myProjectRoutePath = '/12001/modules/srtp/stu/myProject';

  /// 项目详情接口固定的 include 参数（抓包自 stuProjectShow）
  static const String _detailInclude =
      'budget,spend,stus,teas,audits,results,college_export_score,manger_export_score';

  SrtpService({required SharedHttpClient client})
      : _scjx2 = Scjx2ApiService(client: client);

  /// 获取缓存的 JWT token
  Future<String?> getAuthToken() => _scjx2.getAuthToken(moduleId: moduleId);

  /// 清除 JWT token
  Future<void> clearAuthToken() => _scjx2.clearAuthToken(moduleId: moduleId);

  /// 是否已登录
  Future<bool> isLoggedIn() => _scjx2.isLoggedIn(moduleId: moduleId);

  /// 引导登录（zxcas → 提取 key1 → 缓存 token + cookie）
  Future<bool> bootstrapLogin() => _scjx2.bootstrapLogin(moduleId: moduleId);

  /// 拉取"我参与的项目"列表（分页）
  ///
  /// 接口：`POST /srtp/srtp/myProject/listIsMeJoinProjectsPage`
  /// 首屏 body 与抓包一致传 `{}`（服务端默认第 1 页 10 条）；
  /// 加载更多时补传 `{currpage, pagesize}`（与 race 模块同架构，服务端兼容）。
  Future<SrtpProjectPageResult> fetchMyJoinedProjects({
    int page = 1,
    int pageSize = 10,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'srtp_join_list_${page}_$pageSize';
    if (!forceRefresh) {
      final cached = DataCache().get<SrtpProjectPageResult>(cacheKey);
      if (cached != null) return cached;
    }

    final body = <String, dynamic>{
      // 首屏与抓包一致：空对象；后续页带分页参数
      if (page > 1 || pageSize != 10) 'currpage': page,
      if (page > 1 || pageSize != 10) 'pagesize': pageSize,
    };
    final json = await _scjx2.request(
      path: '/srtp/srtp/myProject/listIsMeJoinProjectsPage',
      data: body,
      currentRoutePath: currentRoutePath,
      apiName: 'SRTP',
      moduleId: moduleId,
    );
    final result = SrtpProjectPageResult.fromJson(json);
    DataCache().set(cacheKey, result);
    return result;
  }

  /// 拉取项目详情（含成员/教师/审核/成果/经费）
  ///
  /// 接口：`POST /srtp/srtp/common/stuProjectShow`
  /// body 与抓包一致：include 固定串 + stage 0 + role other（"我参与"视角）
  /// [routePath] 指定详情请求的 currentRoutePath（"我参与"页与"我申请"页不同），
  /// 不参与 HMAC 计算，仅作为 header 透传。
  Future<SrtpProjectDetail> fetchProjectDetail(
    String projectId, {
    String routePath = currentRoutePath,
  }) async {
    final cacheKey = 'srtp_detail_$projectId';
    final cached = DataCache().get<SrtpProjectDetail>(cacheKey);
    if (cached != null) return cached;

    final body = <String, dynamic>{
      'id': projectId,
      'include': _detailInclude,
      'stage': 0,
      'role': 'other',
    };
    final json = await _scjx2.request(
      path: '/srtp/srtp/common/stuProjectShow',
      data: body,
      currentRoutePath: routePath,
      apiName: 'SRTP',
      moduleId: moduleId,
    );
    final detail = SrtpProjectDetail.fromJson(json);
    DataCache().set(cacheKey, detail);
    return detail;
  }

  /// 拉取"我申请的项目"列表（分页）
  ///
  /// 接口：`POST /srtp/srtp/myProject/listProjectProgressPage`
  /// 首屏 body 与抓包一致传 `{}`；加载更多补传 `{currpage, pagesize}`。
  Future<SrtpAppliedProjectPageResult> fetchMyAppliedProjects({
    int page = 1,
    int pageSize = 10,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'srtp_applied_list_${page}_$pageSize';
    if (!forceRefresh) {
      final cached = DataCache().get<SrtpAppliedProjectPageResult>(cacheKey);
      if (cached != null) return cached;
    }

    final body = <String, dynamic>{
      if (page > 1 || pageSize != 10) 'currpage': page,
      if (page > 1 || pageSize != 10) 'pagesize': pageSize,
    };
    final json = await _scjx2.request(
      path: '/srtp/srtp/myProject/listProjectProgressPage',
      data: body,
      currentRoutePath: myProjectRoutePath,
      apiName: 'SRTP',
      moduleId: moduleId,
    );
    final result = SrtpAppliedProjectPageResult.fromJson(json);
    DataCache().set(cacheKey, result);
    return result;
  }
}
