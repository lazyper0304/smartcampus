import 'dart:convert';

import '../core/http_client.dart';
import 'score.dart';

class ScoreService {
  final SharedHttpClient client;
  final String baseUrl;

  ScoreService({
    required this.client,
    this.baseUrl = 'https://ehall.yibinu.edu.cn',
  });

  Future<ScoreResult> fetchScores(StudentInfo? existingInfo) async {
    final host = Uri.parse(baseUrl).host;
    StudentInfo? info = existingInfo;

    // 0. 尝试获取学生信息（可选，失败不影响成绩查询）
    if (info == null) {
      try {
        await client.get(
          Uri.parse('$baseUrl/appShow?appId=5314637135076659'),
        );
        final resp = await client.get(
          Uri.parse('$baseUrl/jwapp/sys/xsjbxxgl/modules/xsjbxx/cxxsjbxxlb.do?*json=1'),
          headers: _headers(host),
        );
        if (resp.statusCode == 200) {
          final json1 = jsonDecode(resp.body) as Map<String, dynamic>;
          final datas = json1['datas'];
          if (datas is Map) {
            final module = datas['cxxsjbxxlb'];
            if (module is Map) {
              final rows = module['rows'];
              if (rows is List && rows.isNotEmpty) {
                info = StudentInfo.fromJson(rows[0] as Map<String, dynamic>);
              }
            }
          }
        }
      } catch (_) {
        // 学生信息获取失败不影响成绩查询
      }
    }

    // 1. 角色选择接口
    final selectResp = await client.get(
      Uri.parse(
          '$baseUrl/appMultiGroupEntranceList'
          '?r_t=${DateTime.now().millisecondsSinceEpoch}'
          '&appId=4768574631264620&param='),
      headers: _headers(host),
    );
    final selectJson = jsonDecode(selectResp.body) as Map<String, dynamic>;
    final targetUrl =
        selectJson['data']?['groupList']?[0]?['targetUrl']?.toString();
    if (targetUrl == null) throw Exception('获取成绩查询入口失败');

    // 2. 访问成绩查询页
    await client.get(Uri.parse(targetUrl));

    // 3. 调用成绩查询 API
    final querySetting =
        '%5B%7B%22name%22%3A%22SFYX%22%2C%22caption%22%3A%22%E6%98%AF%E5%90%A6%E6%9C%89%E6%95%88%22%2C%22linkOpt%22%3A%22AND%22%2C%22builderList%22%3A%22cbl_m_List%22%2C%22builder%22%3A%22m_value_equal%22%2C%22value%22%3A%221%22%2C%22value_display%22%3A%22%E6%98%AF%22%7D%2C%7B%22name%22%3A%22SHOWMAXCJ%22%2C%22caption%22%3A%22%E6%98%BE%E7%A4%BA%E6%9C%80%E9%AB%98%E6%88%90%E7%BB%A9%22%2C%22linkOpt%22%3A%22AND%22%2C%22builderList%22%3A%22cbl_String%22%2C%22builder%22%3A%22equal%22%2C%22value%22%3A0%2C%22value_display%22%3A%22%E5%90%A6%22%7D%5D';

    final scoreResp = await client.get(
      Uri.parse(
          '$baseUrl/jwapp/sys/cjcx/modules/cjcx/xscjcx.do'
          '?querySetting=$querySetting'
          '&*order=-XNXQDM%2C-KCH%2C-KXH'
          '&pageSize=200'
          '&pageNumber=1'),
      headers: _headers(host),
    );

    if (scoreResp.statusCode == 403) {
      throw Exception('服务器拒绝访问（403），请重新登录');
    }
    if (scoreResp.statusCode != 200) {
      throw Exception('获取成绩失败：HTTP ${scoreResp.statusCode}');
    }

    final j = jsonDecode(scoreResp.body) as Map<String, dynamic>;
    if (j['code']?.toString() != '0') {
      throw Exception('API 返回错误：${j['code']}');
    }

    final rows = (j['datas'] as Map?)?['xscjcx']?['rows'] as List?;
    final scores = <Score>[];
    if (rows != null) {
      for (final row in rows) {
        scores.add(Score.fromJson(row as Map<String, dynamic>));
      }
    }
    return ScoreResult(info: info ?? StudentInfo.empty(), scores: scores);
  }

  Map<String, String> _headers(String host) => {
        'Accept': 'application/json, text/javascript, */*; q=0.01',
        'User-Agent':
            'Mozilla/5.0 (iPhone; CPU iPhone OS 13_2_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0.3 Mobile/15E148 Safari/604.1',
        'Host': host,
        'Origin': baseUrl,
        'Referer': '$baseUrl/jwapp/sys/cjcx/*default/index.do',
        'X-Requested-With': 'XMLHttpRequest',
      };
}

class ScoreResult {
  final StudentInfo info;
  final List<Score> scores;
  const ScoreResult({required this.info, required this.scores});
}
