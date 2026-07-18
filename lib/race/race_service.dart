import 'dart:convert';

import '../core/http_client.dart';
import '../core/data_cache.dart';
import 'race.dart';

/// 学科竞赛服务
///
/// 调用 https://scjx2.yibinu.edu.cn 的 API 获取学生竞赛列表。
/// 流程：先访问入口页触发 CAS SSO 建立会话，再调用 API。
class RaceService {
  final SharedHttpClient client;

  static const String baseUrl = 'https://scjx2.yibinu.edu.cn';

  RaceService({required this.client});

  /// 获取竞赛列表（分页）
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

    // 1) 访问入口页触发 CAS SSO
    await _ensureSession();

    // 2) 调用 API
    final body = <String, dynamic>{'currpage': page, 'pagesize': pageSize};

    final resp = await client.postJson(
      Uri.parse('$baseUrl/race/race/stuRace/listStuRacePage'),
      body: body,
      headers: {
        'Accept': 'application/json, text/plain, */*',
        'Origin': baseUrl,
        'Referer': '$baseUrl/RACE/',
        'currentRoutePath':
            '/9001/modules/sjjx/race/stu/race/stage/list',
      },
    );

    if (resp.statusCode != 200) {
      final snippet = resp.body.length > 200
          ? resp.body.substring(0, 200)
          : resp.body;
      throw Exception('请求失败 (HTTP ${resp.statusCode})\n$snippet');
    }

    final raw = jsonDecode(resp.body) as Map<String, dynamic>;
    final code = raw['code'];
    if (code != 200) {
      throw Exception(raw['msg']?.toString() ?? 'API 返回错误: $code');
    }

    final result = RacePageResult.fromJson(raw);
    DataCache().set(cacheKey, result);
    return result;
  }

  /// 访问入口页触发 CAS SSO
  Future<void> _ensureSession() async {
    try {
      await client.get(
        Uri.parse('$baseUrl/RACE/'),
        headers: {
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8',
          'Upgrade-Insecure-Requests': '1',
        },
      );
      // CAS 重定向链需要时间完成
      await Future.delayed(const Duration(milliseconds: 800));
    } catch (_) {
      // CAS 重定向可能因跨域产生异常，不影响后续请求
    }
  }
}
