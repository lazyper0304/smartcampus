import 'dart:convert';

import 'package:http/http.dart' as http;

import 'erke_models.dart';

/// 第二课堂服务（erke.yibinu.edu.cn）。
///
/// 与「智慧校园 / CAS」完全独立：账号密码登录拿 JWT token，
/// 之后所有接口用 `Authorization: Bearer <token>` 鉴权。
/// 仅校园内网可访问。
class ErkeService {
  static const String baseUrl = 'https://erke.yibinu.edu.cn';
  static const String _loginUrl = '$baseUrl/prod-api/login';
  static const String _transcriptUrl = '$baseUrl/prod-api/transcript/item';

  /// 账号密码登录，成功返回 token。失败抛 [Exception]。
  static Future<String> login(String username, String password) async {
    final resp = await http.post(
      Uri.parse(_loginUrl),
      headers: {
        'Content-Type': 'application/json;charset=UTF-8',
        'Accept': 'application/json, text/plain, */*',
      },
      body: jsonEncode({'username': username, 'password': password}),
    );
    final j = jsonDecode(resp.body) as Map<String, dynamic>;
    if (j['code']?.toString() != '200') {
      throw Exception(j['msg']?.toString() ?? '登录失败（code=${j['code']}）');
    }
    final token = j['token']?.toString();
    if (token == null || token.isEmpty) {
      throw Exception('登录成功，但未返回 token');
    }
    return token;
  }

  /// 获取第二课堂成绩单。token 失效时抛 [ErkeAuthExpiredException]。
  static Future<ErkeTranscript> fetchTranscript(
      String username, String token) async {
    final resp = await http.get(
      Uri.parse('$_transcriptUrl/$username'),
      headers: {
        'Accept': 'application/json, text/plain, */*',
        'Authorization': 'Bearer $token',
      },
    );
    if (resp.statusCode == 401 || resp.statusCode == 403) {
      throw const ErkeAuthExpiredException();
    }
    if (resp.statusCode != 200) {
      throw Exception('获取第二课堂成绩失败：HTTP ${resp.statusCode}');
    }
    final j = jsonDecode(resp.body) as Map<String, dynamic>;
    if (j['code']?.toString() != '200') {
      throw Exception(j['msg']?.toString() ?? '接口返回错误（code=${j['code']}）');
    }
    final data = j['data'];
    if (data is! Map) throw Exception('返回数据格式异常');
    return ErkeTranscript.fromJson(data as Map<String, dynamic>);
  }
}

/// 登录过期异常（token 失效，需要重新登录）
class ErkeAuthExpiredException implements Exception {
  const ErkeAuthExpiredException();

  @override
  String toString() => '登录已过期，请重新登录';
}
