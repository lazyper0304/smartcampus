import 'dart:async';
import 'dart:convert';

import 'package:gbk_codec/gbk_codec.dart';

import '../core/http_client.dart';
import '../core/data_cache.dart';
import 'jiaocai.dart';

/// 教材查询服务
class JiaocaiService {
  final SharedHttpClient client;
  final String baseUrl = 'https://ehall.yibinu.edu.cn';
  final String? studentId;

  JiaocaiService(this.client, {this.studentId});

  Future<List<TextbookOrder>> fetchOrders({bool forceRefresh = false}) async {
    const cacheKey = 'jiaocai_orders';
    if (!forceRefresh) {
      final cached = DataCache().get<List<TextbookOrder>>(cacheKey);
      if (cached != null) return cached;
    }

    final items = await _fetchViaHttp();
    DataCache().set(cacheKey, items);
    return items;
  }

  Future<List<TextbookOrder>> _fetchViaHttp() async {
    final host = Uri.parse(baseUrl).host;

    // 1. 角色选择入口
    await _entranceFlow(host);

    // 2. 访问成绩查询首页
    await client.get(
      Uri.parse('$baseUrl/jwapp/sys/cjcx/*default/index.do'),
      headers: _htmlHeaders(host),
    );

    // 3. POST 获取报表配置
    String bbwid = '';
    try {
      final configResp = await client.postForm(
        Uri.parse('$baseUrl/jwapp/sys/jwpubapp/modules/bb/cxjwggbbcs.do'),
        body: {'*search': 'true', 'pageSize': '999'},
        headers: {
          'Accept': 'application/json, text/javascript, */*; q=0.01',
          'Host': host,
          'Origin': baseUrl,
          'Referer': '$baseUrl/jwapp/sys/cjcx/*default/index.do',
          'X-Requested-With': 'XMLHttpRequest',
        },
      );
      if (configResp.statusCode == 200) {
        final j = jsonDecode(configResp.body) as Map<String, dynamic>;
        final rows = (j['datas'] as Map?)?['cxjwggbbcs']?['rows'] as List?;
        if (rows != null && rows.isNotEmpty) {
          bbwid = rows[0]['BBWID']?.toString() ?? '';
        }
      }
    } catch (_) {}
    if (bbwid.isEmpty) throw Exception('未获取到报表配置');

    final xh = studentId ?? '';

    // 4. GET 获取 BBKEY 表单
    final firstResp = await client.get(
      Uri.parse('$baseUrl/jwapp/sys/frReport2/show.do'
          '?reportlet=cjcx/xsjcdgfytj.cpt'
          '&yxdm=&xnxqdm=&XH=$xh&BBWID=$bbwid'),
      headers: _htmlHeaders(host),
    );
    if (firstResp.statusCode != 200 || !firstResp.body.contains('BBKEY')) {
      throw Exception('获取报表表单失败');
    }

    // 解析表单参数
    final bbkey = _extract(firstResp.body, r'name="BBKEY"\s+value="([^"]*)"');
    final formYxdm = _extract(firstResp.body, r'name="yxdm"\s+value="([^"]*)"');
    final formXnxqdm =
        _extract(firstResp.body, r'name="xnxqdm"\s+value="([^"]*)"');
    final formReportlet =
        _extract(firstResp.body, r'name="reportlet"\s+value="([^"]+)"',
            defaultVal: 'cjcx/xsjcdgfytj.cpt');
    final formXh =
        _extract(firstResp.body, r'name="XH"\s+value="([^"]+)"', defaultVal: xh);
    if (bbkey.isEmpty) throw Exception('未获取到 BBKEY');

    // 5. POST 提交表单
    var formResp = await client.postForm(
      Uri.parse('$baseUrl/jwapp/sys/frReport2/show.do'),
      body: {
        'BBKEY': bbkey,
        'yxdm': formYxdm,
        'reportlet': formReportlet,
        'XH': formXh,
        'xnxqdm': formXnxqdm,
      },
      headers: {
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8',
        'Host': host,
        'Origin': baseUrl,
        'Referer':
            '$baseUrl/jwapp/sys/frReport2/show.do'
            '?reportlet=$formReportlet&yxdm=&xnxqdm=&XH=$xh&BBWID=$bbwid',
        'Upgrade-Insecure-Requests': '1',
      },
      noRedirect: true,
    );

    // 手动跟随 302（POST 不会被 dart:io 自动跟随）
    if (formResp.statusCode == 302 || formResp.statusCode == 301) {
      final location = formResp.header('location') ?? '';
      if (location.isNotEmpty) {
        final redirectUri = location.startsWith('http')
            ? Uri.parse(location)
            : Uri.parse('$baseUrl$location');
        formResp = await client.get(redirectUri,
            headers: _htmlHeaders(redirectUri.host));
      }
    } else if (formResp.statusCode != 200) {
      throw Exception('提交报表表单失败：HTTP ${formResp.statusCode}');
    }

    // 6. 解析 sessionID
    String? sessionId;
    final sm = RegExp(r"FR\.SessionMgr\.register\('(\d+)'")
        .firstMatch(formResp.body);
    if (sm != null) sessionId = sm.group(1);
    if (sessionId == null) {
      final am = RegExp(r"currentSessionID\s*=\s*'(\d+)'")
          .firstMatch(formResp.body);
      if (am != null) sessionId = am.group(1);
    }
    if (sessionId == null || sessionId.isEmpty) {
      throw Exception('未获取到报表会话');
    }

    // 7. 使用 getRaw 获取报表数据（frReport2 返回 GBK 编码）
    final dataRaw = await client.getRaw(
      Uri.parse('$baseUrl/jwapp/sys/frReport2/show.do'
          '?_=${DateTime.now().millisecondsSinceEpoch}'
          '&__boxModel__=true'
          '&op=page_content'
          '&sessionID=$sessionId'
          '&pn=1'),
      headers: {
        'Accept': 'text/html, */*; q=0.01',
        'Host': host,
        'Referer': '$baseUrl/jwapp/sys/frReport2/show.do',
        'X-Requested-With': 'XMLHttpRequest',
      },
    );

    if (dataRaw.statusCode == 403) throw Exception('服务器拒绝访问（403）');
    if (dataRaw.statusCode == 302) throw Exception('会话已过期');
    if (dataRaw.statusCode != 200) {
      throw Exception('获取报表数据失败：HTTP ${dataRaw.statusCode}');
    }

    // 检测 charset 并解码
    final html = _decodeWithCharset(dataRaw.bodyBytes, dataRaw);
    return _parseHtmlTable(html);
  }

  /// 智能解码：从 Content-Type 或 HTML meta 检测 charset
  String _decodeWithCharset(List<int> bytes, RawResponse resp) {
    // 先检测 Content-Type 头中的 charset
    String? charset;
    final ct = resp.header('content-type') ?? '';
    final ctMatch = RegExp(r'charset\s*=\s*([^\s;]+)', caseSensitive: false)
        .firstMatch(ct);
    if (ctMatch != null) charset = ctMatch.group(1)!.toLowerCase();

    // 尝试 UTF-8 解码
    final asUtf8 = utf8.decode(bytes, allowMalformed: true);

    // 如果 Content-Type 指定了 GBK 或中文出现乱码，尝试 GBK
    if (charset != null &&
        (charset.contains('gbk') || charset.contains('gb2312') ||
         charset.contains('gb18030'))) {
      return _decodeGbk(bytes);
    }

    // 检查 HTML meta 中的 charset
    if (asUtf8.contains('charset') &&
        RegExp(r'charset\s*=\s*(gbk|gb2312|gb18030)', caseSensitive: false)
            .hasMatch(asUtf8)) {
      return _decodeGbk(bytes);
    }

    // 检查是否有无法解码的中文字符（检查常见 GBK 特征）
    if (asUtf8.contains('A') &&
        RegExp(r'[\u4e00-\u9fff]').allMatches(asUtf8).isEmpty &&
        bytes.any((b) => b > 127)) {
      // 有非 ASCII 字节但没有中文字符 → 可能是 GBK 乱码
      return _decodeGbk(bytes);
    }

    return asUtf8;
  }

  /// GBK 解码
  String _decodeGbk(List<int> bytes) {
    try {
      return gbk_bytes.decode(bytes);
    } catch (_) {
      return utf8.decode(bytes, allowMalformed: true);
    }
  }

  List<TextbookOrder> _parseHtmlTable(String html) {
    final orders = <TextbookOrder>[];
    final rowPattern =
        RegExp(r'<tr[^>]*tridx="([^"]*)"[^>]*>(.*?)</tr>', dotAll: true);
    for (final row in rowPattern.allMatches(html)) {
      final tridx = int.tryParse(row.group(1) ?? '') ?? 0;
      if (tridx < 4) continue;
      final cells = RegExp(r'<td[^>]*>(.*?)</td>', dotAll: true)
          .allMatches(row.group(2) ?? '')
          .toList();
      if (cells.length < 11) continue;
      String ct(int idx) => cells[idx]
          .group(1)!
          .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final semester = ct(1);
      if (semester.isEmpty) continue;
      orders.add(TextbookOrder(
        semester: semester,
        grade: ct(2),
        quantity: int.tryParse(ct(5).replaceAll(RegExp(r'[^\d]'), '')) ?? 0,
        totalPrice:
            double.tryParse(ct(6).replaceAll(RegExp(r'[^\d.]'), '')) ?? 0,
        department: ct(7),
        major: ct(8),
        className: ct(9).replaceAll(RegExp(r'\s*\(.*?\)'), ''),
        books: _parseBooks(ct(10)),
      ));
    }
    return orders;
  }

  List<TextbookBook> _parseBooks(String raw) {
    final books = <TextbookBook>[];
    for (final m
        in RegExp(r'【([^[\]]+)\[([^\]]+)\][^】]*】').allMatches(raw)) {
      final isbn = m.group(1)?.trim() ?? '';
      final name = m.group(2)?.trim() ?? '';
      if (name.isEmpty) continue;
      final priceM = RegExp(r'=(\d+\.?\d*)元').firstMatch(m.group(0) ?? '');
      final price = priceM != null ? double.parse(priceM.group(1)!) : 0.0;
      books.add(TextbookBook(isbn: isbn, name: name, price: price));
    }
    return books;
  }

  Future<void> _entranceFlow(String host) async {
    try {
      final resp = await client.get(
        Uri.parse(
            '$baseUrl/appMultiGroupEntranceList?r_t=${DateTime.now().millisecondsSinceEpoch}&appId=4768574631264620&param='),
        headers: {
          'Accept': 'application/json, text/javascript, */*; q=0.01',
          'Host': host,
          'Referer': '$baseUrl/jwapp/sys/cjcx/*default/index.do',
          'X-Requested-With': 'XMLHttpRequest',
        },
      );
      if (resp.statusCode == 200) {
        final j = jsonDecode(resp.body) as Map<String, dynamic>;
        final targetUrl =
            j['data']?['groupList']?[0]?['targetUrl']?.toString();
        if (targetUrl != null && targetUrl.isNotEmpty) {
          await client.get(Uri.parse(targetUrl));
        }
      }
    } catch (_) {}
  }

  String _extract(String html, String pattern, {String defaultVal = ''}) {
    return RegExp(pattern).firstMatch(html)?.group(1) ?? defaultVal;
  }

  Map<String, String> _htmlHeaders(String host) => {
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8',
        'Host': host,
        'Upgrade-Insecure-Requests': '1',
      };
}
