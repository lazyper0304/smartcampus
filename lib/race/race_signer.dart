import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// scjx2.yibinu.edu.cn RACE 系统 API 签名工具
///
/// 通过分析前端 JavaScript 源码（race_main.js）逆向出的两个签名算法：
/// - signature: HMAC-SHA512("{timestamp}-{nonce}", "zxtd_256-bit-secret-key-2025-8-7")
/// - zhxhsign:   HMAC-SHA256(serialized_params, "zhxintd201020301")
class RaceApiSigner {
  /// signature 密钥（HMAC-SHA512）
  static const String _signatureKey = 'zxtd_256-bit-secret-key-2025-8-7';

  /// zhxhsign 密钥（HMAC-SHA256）
  static const String _zhxhKey = 'zhxintd201020301';

  /// 当前路由路径（来自 currentRoutePath 头）
  static const String currentRoutePath =
      '/9001/modules/sjjx/race/stu/race/stage/list';

  final Random _random = Random();

  /// 生成 signature 所需的三个字段
  ///
  /// 返回 (timestamp, nonce, signature)
  /// - timestamp: 毫秒时间戳字符串（可叠加时钟偏移 tdf）
  /// - nonce: 26 字符随机串
  /// - signature: HMAC-SHA512(timestamp + "-" + nonce, key) 的 hex
  ({String timestamp, String nonce, String signature}) generateSignature({
    int timeDeltaFromServer = 0,
  }) {
    final timestampMs = DateTime.now().millisecondsSinceEpoch + timeDeltaFromServer;
    final timestamp = timestampMs.toString();
    final nonce = _generateNonce();
    final message = '$timestamp-$nonce';
    final hmac = Hmac(sha512, utf8.encode(_signatureKey));
    final digest = hmac.convert(utf8.encode(message));
    return (timestamp: timestamp, nonce: nonce, signature: digest.toString());
  }

  /// 生成 zhxhsign
  ///
  /// 模拟前端 2fd1 模块的 u() + d() + g() 流程：
  /// 1. 把 data 扁平化为 {key: [values]} 形式
  /// 2. 按 localeCompare zh-CN 排序 key
  /// 3. 拼成 key=value 格式（无分隔符）
  /// 4. HMAC-SHA256(序列化字符串, "zhxintd201020301")
  String generateZhxhSign(Map<String, dynamic>? data, [Map<String, dynamic>? params]) {
    // 1. 扁平化到 {key: [values]}（同 2fd1 模块的 p/m 函数）
    final flat = <String, List<String>>{};
    if (data != null) {
      _flatten(data, '', flat);
    }
    // 2. 排序 key（localeCompare zh-CN 在 ASCII 字符串上等价于普通字典序）
    final keys = flat.keys.toList()..sort();
    // 3. 拼成 key=value 格式
    final buffer = StringBuffer();
    for (final k in keys) {
      final values = flat[k]!;
      // 前端 i.sort() 是无参排序（默认字典序，对 String 列表是按代码点）
      values.sort();
      if (values.isNotEmpty) {
        for (final v in values) {
          buffer.write('$k=$v');
        }
      } else {
        buffer.write('$k=');
      }
    }
    // 4. HMAC-SHA256
    final hmac = Hmac(sha256, utf8.encode(_zhxhKey));
    final digest = hmac.convert(utf8.encode(buffer.toString()));
    return digest.toString().toUpperCase();
  }

  /// 递归把对象/数组扁平化到 {key: [values]}
  ///
  /// 简单值（string/number/bool/null）进入 list
  /// 嵌套对象用 prefix 路径（但前端是直接用原始 key，不再加点号分隔）
  /// 实际前端 2fd1 模块对嵌套对象的处理有 bug（写 module-level n 而非局部 n），
  /// 实践中 API 调用都用扁平对象，无需关心
  void _flatten(Object? value, String prefix, Map<String, List<String>> out) {
    if (value == null) return;
    if (value is Map) {
      value.forEach((k, v) {
        final keyStr = k.toString();
        if (v is Map || v is List) {
          _flatten(v, keyStr, out);
        } else {
          _addToBucket(out, keyStr, _stringify(v));
        }
      });
    } else if (value is List) {
      for (final item in value) {
        if (item is Map || item is List) {
          _flatten(item, prefix, out);
        } else {
          _addToBucket(out, prefix, _stringify(item));
        }
      }
    } else {
      if (prefix.isNotEmpty) {
        _addToBucket(out, prefix, _stringify(value));
      }
    }
  }

  void _addToBucket(Map<String, List<String>> out, String key, String value) {
    final list = out.putIfAbsent(key, () => <String>[]);
    list.add(value);
  }

  String _stringify(Object? v) {
    if (v == null) return '';
    if (v is String) return v;
    if (v is bool) return v.toString();
    if (v is num) return v.toString();
    return v.toString();
  }

  /// 生成 26 字符随机 nonce
  ///
  /// 等价于 JS 的：
  /// Math.random().toString(36).substring(2,15) +
  /// Math.random().toString(36).substring(2,15)
  String _generateNonce() {
    return _randomBase36(13) + _randomBase36(13);
  }

  /// 生成 n 字符的 base36 随机串
  String _randomBase36(int n) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final buf = StringBuffer();
    for (int i = 0; i < n; i++) {
      buf.write(chars[_random.nextInt(chars.length)]);
    }
    return buf.toString();
  }

  /// 构造 RACE API 所需的所有签名请求头
  ///
  /// 返回的 Map 包含：
  /// - nonce / timestamp / signature: HmacSHA512 签名
  /// - zhxhsign: HmacSHA256 签名
  /// - random: 当前时间戳（无服务端时钟校准时）
  /// - currentRoutePath: 前端路由路径
  /// - MenuId: 可选（前端从 sessionStorage 取）
  Map<String, String> buildHeaders({
    required Map<String, dynamic>? data,
    Map<String, dynamic>? params,
    String? menuId,
    String? authorization,
  }) {
    final sig = generateSignature();
    final zhxh = generateZhxhSign(data, params);
    final random = DateTime.now().millisecondsSinceEpoch;

    final headers = <String, String>{
      'nonce': sig.nonce,
      'timestamp': sig.timestamp,
      'signature': sig.signature,
      'zhxhsign': zhxh,
      'random': random.toString(),
      'currentRoutePath': currentRoutePath,
      'MenuId': menuId ?? '',
      'X-Requested-With': 'XMLHttpRequest',
    };
    if (authorization != null && authorization.isNotEmpty) {
      headers['Authorization'] = authorization;
    }
    return headers;
  }
}
