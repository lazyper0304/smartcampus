import '../core/bingo/bingo_client.dart';
import 'erke_models.dart';

/// Bingo 第二课堂服务（`GET /erke/summary`、`GET /erke/activities`）。
///
/// 替代原 `erke.yibinu.edu.cn` 直连：该站需独立账号密码登录拿 JWT，
/// 且**仅校园内网可访问**，用户在 VPN 之外完全打不开。现改由 Bingo 后端
/// 代理（后端读第二课堂只读库），App 侧不再需要第二次登录、也不再受内网限制。
///
/// 输出沿用既有 UI 模型（[ErkeTranscript] 等），第二课堂页面无需改动。
class BingoErkeService {
  BingoErkeService._();

  static final BingoErkeService instance = BingoErkeService._();

  final BingoClient _client = BingoClient.instance;

  /// 完整成绩单：分类汇总 + 活动列表 + 学生信息。
  ///
  /// 两个接口任一失败都不阻断另一部分（与首页聚合接口同样的降级策略）。
  Future<ErkeTranscript> fetchTranscript({bool forceRefresh = false}) async {
    List<ErkeReportItem> report = const [];
    List<ErkeTranscriptItem> items = const [];

    try {
      // /erke/summary 的 data 直接是**数组**
      final rawSummary = await _client.getList('/erke/summary');
      report = rawSummary
          .map((e) => ErkeReportItem.fromBingoJson(
              e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      // 汇总失败不阻断活动列表
    }

    try {
      // /erke/activities 的 data 是 { items[], syncing }
      final data = await _client.getMap('/erke/activities');
      final rawItems = data['items'] as List<dynamic>? ?? const [];
      items = rawItems
          .map((e) => ErkeTranscriptItem.fromBingoJson(
              e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      // 活动列表失败不阻断汇总
    }

    return ErkeTranscript(
      profile: await _profile(),
      report: report,
      items: items,
    );
  }

  /// 后台是否正在同步第二课堂数据
  Future<bool> isSyncing() async {
    try {
      final data = await _client.getMap('/erke/activities');
      return data['syncing'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 学生信息来自登录时下发的 user（第二课堂侧不再单独登录）
  Future<ErkeProfile> _profile() async {
    final user = await BingoClient.loadUserInfo();
    if (user == null) return const ErkeProfile.empty();
    return ErkeProfile(
      unitName: user['college']?.toString() ?? '',
      classNo: user['class_name']?.toString() ?? '',
      nickName: user['real_name']?.toString() ?? user['nickname']?.toString() ?? '',
      username: user['school_id']?.toString() ?? '',
      avatar: user['avatar']?.toString(),
    );
  }
}