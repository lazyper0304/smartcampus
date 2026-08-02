import 'dart:convert';

import '../core/http_client.dart';
import '../core/data_cache.dart';
import 'kxjas.dart';

/// 空闲教室查询（kxjas）服务
///
/// 对应 ehall jwapp 应用「空闲教室」：
/// - [ensureSession]：GET index.do 预热模块会话（kcbcx 同款范式）
/// - [fetchBuildings]：教学楼列表（jxlcx.do，循环拉全量并缓存）
/// - [fetchFreeClassrooms]：空闲教室查询（cxjsqk.do，实时无缓存）
/// - [fetchCurrentWeek]：当前教学周次（dqzc.do，复用 wdkb 模块接口）
class KxjasService {
  final SharedHttpClient client;
  final String baseUrl;

  KxjasService({
    required this.client,
    this.baseUrl = 'https://ehall.yibinu.edu.cn',
  });

  String get _host => Uri.parse(baseUrl).host;

  /// 当前学期代码（如 "2025-2026-2"），与 course 模块口径一致
  String get defaultXnxqdm {
    final now = DateTime.now();
    return now.month >= 2 && now.month <= 7
        ? '${now.year - 1}-${now.year}-2'
        : '${now.year}-${now.year + 1}-1';
  }

  // ==================== 会话预热 ====================

  /// GET kxjas 首页建立模块级会话（后续 POST 需要）
  Future<void> ensureSession() async {
    final host = _host;
    try {
      await client.get(
        Uri.parse('$baseUrl/jwapp/sys/kxjas/*default/index.do'),
        headers: {
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8',
          'Host': host,
          'Upgrade-Insecure-Requests': '1',
        },
      );
    } catch (_) {}
  }

  // ==================== 当前教学周次 ====================

  /// 从 dqzc.do（wdkb 模块）获取当前教学周次
  Future<int> fetchCurrentWeek({String? xnxqdm}) async {
    final host = _host;
    final today = DateTime.now();
    final xnq = _parseXnxq(xnxqdm ?? defaultXnxqdm);
    final resp = await client.postForm(
      Uri.parse('$baseUrl/jwapp/sys/wdkb/modules/jshkcb/dqzc.do'),
      body: {
        'XN': xnq[0],
        'XQ': xnq[1],
        'RQ': '${today.year}-${today.month}-${today.day}',
      },
      headers: _formHeaders(host),
      noRedirect: true,
    );
    if (resp.statusCode == 302) {
      throw Exception('会话已过期，请重新登录（HTTP 302）');
    }
    if (resp.statusCode != 200) {
      throw Exception('获取当前周次失败：HTTP ${resp.statusCode}');
    }
    try {
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final datas = json['datas'] as Map?;
      final module = datas?['dqzc'] as Map?;
      final rows = module?['rows'] as List?;
      if (rows != null && rows.isNotEmpty) {
        final zc = int.tryParse((rows[0] as Map)['ZC']?.toString() ?? '') ?? 1;
        if (zc > 0) return zc;
      }
    } catch (_) {}
    return 1;
  }

  // ==================== 教学楼列表 ====================

  /// 拉取全部教学楼（jxlcx.do，默认 pageSize=200 循环拉全量并缓存）
  Future<List<KxjasBuilding>> fetchBuildings({bool forceRefresh = false}) async {
    const cacheKey = 'kxjas_buildings';
    if (!forceRefresh) {
      final cached = DataCache().get<List<KxjasBuilding>>(cacheKey);
      if (cached != null) return cached;
    }
    await ensureSession();
    final host = _host;

    final buildings = <KxjasBuilding>[];
    int page = 1;
    int total = 0;
    while (true) {
      final resp = await client.postForm(
        Uri.parse('$baseUrl/jwapp/sys/kxjas/modules/kxjas/jxlcx.do'),
        body: {
          '*order': '+XXXQDM,+PX,+JXLDM',
          'pageSize': '200',
          'pageNumber': page.toString(),
        },
        headers: _formHeaders(host),
        noRedirect: true,
      );
      if (resp.statusCode == 302) {
        throw Exception('会话已过期，请重新登录（HTTP 302）');
      }
      if (resp.statusCode != 200) break;
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      if (json['code']?.toString() != '0') break;
      final datas = json['datas'];
      if (datas is! Map) break;
      final module = datas['jxlcx'];
      if (module is! Map) break;
      final rows = module['rows'];
      if (rows is! List || rows.isEmpty) break;
      buildings.addAll(
          rows.map((r) => KxjasBuilding.fromJson(r as Map<String, dynamic>)));
      total = int.tryParse(module['totalSize']?.toString() ?? '') ?? 0;
      if (buildings.length >= total) break;
      page++;
    }
    DataCache().set(cacheKey, buildings);
    return buildings;
  }

  // ==================== 大节（节次时段）列表 ====================

  /// 拉取大节列表（cxjcqk.do，如 "1-2节 08:30-10:05"），缓存
  Future<List<KxjasPeriod>> fetchPeriods({
    String? xnxqdm,
    bool forceRefresh = false,
  }) async {
    final key = 'kxjas_periods_${xnxqdm ?? defaultXnxqdm}';
    if (!forceRefresh) {
      final cached = DataCache().get<List<KxjasPeriod>>(key);
      if (cached != null) return cached;
    }
    await ensureSession();
    final host = _host;
    try {
      final resp = await client.postForm(
        Uri.parse('$baseUrl/jwapp/sys/kxjas/modules/kxjas/cxjcqk.do'),
        body: {'XNXQDM': xnxqdm ?? defaultXnxqdm},
        headers: _formHeaders(host),
        noRedirect: true,
      );
      if (resp.statusCode == 302) {
        throw Exception('会话已过期，请重新登录（HTTP 302）');
      }
      if (resp.statusCode != 200) {
        throw Exception('获取节次时段失败：HTTP ${resp.statusCode}');
      }
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      if (json['code']?.toString() != '0') return [];
      final datas = json['datas'];
      if (datas is! Map) return [];
      final module = datas['cxjcqk'];
      if (module is! Map) return [];
      final rows = module['rows'];
      if (rows is! List) return [];
      final periods = rows
          .map((r) => KxjasPeriod.fromJson(r as Map<String, dynamic>))
          .toList();
      DataCache().set(key, periods);
      return periods;
    } catch (e) {
      if (e is Exception && e.toString().contains('会话已过期')) rethrow;
      return [];
    }
  }

  // ==================== 空闲教室查询 ====================

  /// 按 学期 + 周次 + 星期（+可选教学楼 +可选大节）查询空闲教室（cxjsqk.do）
  ///
  /// - [week]: 教学周次（ZC）
  /// - [day]: 星期（XQ，1=周一 ~ 7=周日）
  /// - [jxldm]: 教学楼代码，空字符串表示全校
  /// - [period]: 大节序号（DJ，[KxjasPeriod.dj]），0 表示全部节次
  Future<KxjasPageResult> fetchFreeClassrooms({
    String? xnxqdm,
    required int week,
    required int day,
    String jxldm = '',
    int period = 0,
    int pageSize = 20,
    int pageNumber = 1,
  }) async {
    await ensureSession();
    final host = _host;

    final conditions = <Map<String, String>>[
      if (jxldm.isNotEmpty)
        {
          'name': 'JXLDM',
          'caption': '教学楼代码',
          'builder': 'equal',
          'linkOpt': 'AND',
          'value': jxldm,
        },
      if (period > 0)
        {
          'name': 'DJ',
          'caption': '大节',
          'builder': 'equal',
          'linkOpt': 'AND',
          'value': period.toString(),
        },
    ];
    final querySetting = jsonEncode(conditions);

    final resp = await client.postForm(
      Uri.parse('$baseUrl/jwapp/sys/kxjas/modules/kxjas/cxjsqk.do'),
      body: {
        'XNXQDM': xnxqdm ?? defaultXnxqdm,
        'ZC': week.toString(),
        'XQ': day.toString(),
        'querySetting': querySetting,
        '*order': '+LC,+JASMC',
        'pageSize': pageSize.toString(),
        'pageNumber': pageNumber.toString(),
      },
      headers: _formHeaders(host),
      noRedirect: true,
    );
    if (resp.statusCode == 302) {
      throw Exception('会话已过期，请重新登录（HTTP 302）');
    }
    if (resp.statusCode == 403) {
      throw Exception('服务器拒绝访问（403）');
    }
    if (resp.statusCode != 200) {
      throw Exception('查询空闲教室失败：HTTP ${resp.statusCode}');
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    if (json['code']?.toString() != '0') {
      throw Exception('API 返回错误：${json['code']}');
    }
    final datas = json['datas'];
    if (datas is! Map) {
      return KxjasPageResult(
          rows: const [], totalSize: 0, pageNumber: pageNumber, pageSize: pageSize);
    }
    final module = datas['cxjsqk'];
    if (module is! Map) {
      return KxjasPageResult(
          rows: const [], totalSize: 0, pageNumber: pageNumber, pageSize: pageSize);
    }
    final rows = module['rows'];
    final classrooms = rows is List
        ? rows
            .map((r) => KxjasClassroom.fromJson(r as Map<String, dynamic>))
            .toList()
        : <KxjasClassroom>[];
    return KxjasPageResult(
      rows: classrooms,
      totalSize: int.tryParse(module['totalSize']?.toString() ?? '') ?? 0,
      pageNumber: int.tryParse(module['pageNumber']?.toString() ?? '') ?? pageNumber,
      pageSize: int.tryParse(module['pageSize']?.toString() ?? '') ?? pageSize,
    );
  }

  // ==================== 内部工具 ====================

  /// 从 xnxqdm（如 "2025-2026-2"）解析 XN 和 XQ
  List<String> _parseXnxq(String xnxqdm) {
    final parts = xnxqdm.split('-');
    if (parts.length >= 3) {
      return ['${parts[0]}-${parts[1]}', parts[2]];
    }
    return ['', ''];
  }

  /// kxjas 模块表单请求头（Referer 指向 kxjas 首页）
  Map<String, String> _formHeaders(String host) => {
        'Accept': 'application/json, text/javascript, */*; q=0.01',
        'Host': host,
        'Origin': 'https://ehall.yibinu.edu.cn',
        'Referer':
            'https://ehall.yibinu.edu.cn/jwapp/sys/kxjas/*default/index.do',
        'X-Requested-With': 'XMLHttpRequest',
      };
}
