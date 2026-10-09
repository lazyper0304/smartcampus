import 'bingo_erke_service.dart';
import 'erke_models.dart';

/// 第二课堂服务（数据源：Bingo 后端 `/erke/*`）。
///
/// 原实现直连 `erke.yibinu.edu.cn` 并维护一套独立的账号密码登录
/// （`ErkeAuthExpiredException` 与独立登录页已随之移除）：该站仅校园内网
/// 可访问，且需要用户第二次输入账号密码。现统一走 Bingo 后端代理，
/// 复用双下放登录的凭证，实现「一次登录全部可用」。
class ErkeService {
  ErkeService._();

  static final ErkeService instance = ErkeService._();

  /// 拉取第二课堂成绩单（分类汇总 + 活动记录）
  ///
  /// [username] / [token] 仅为兼容旧调用签名，已不再用于网络请求。
  Future<ErkeTranscript> fetchTranscript({
    String? username,
    String? token,
    bool forceRefresh = false,
  }) =>
      BingoErkeService.instance.fetchTranscript(forceRefresh: forceRefresh);

  /// 后台是否正在同步（页面可显示「同步中」）
  Future<bool> isSyncing() => BingoErkeService.instance.isSyncing();
}