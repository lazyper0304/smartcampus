import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// scjx2.yibinu.edu.cn 通用 API 签名工具
///
/// 通过分析前端 JavaScript 源码（race_main.js）逆向出的两个签名算法：
/// - signature: HMAC-SHA512("{timestamp}-{nonce}", "zxtd_256-bit-secret-key-2025-8-7")
/// - zhxhsign:   HMAC-SHA256(serialized_params, "zhxintd201020301")
///
/// 适用于 scjx2 下所有子模块（race、teach、practice、graduation 等），
/// 不同的子模块使用不同的 currentRoutePath（在调用 buildHeaders 时传入）。
class Scjx2ApiSigner {
  /// signature 密钥（HMAC-SHA512）
  static const String _signatureKey = 'zxtd_256-bit-secret-key-2025-8-7';

  /// zhxhsign 密钥（HMAC-SHA256）
  static const String _zhxhKey = 'zhxintd201020301';

  final Random _random = Random();

  /// 生成 signature 所需的三个字段
  ///
  /// 返回 (timestamp, nonce, signature)
  /// - timestamp: 毫秒时间戳字符串
  /// - nonce: 26 字符随机串
  /// - signature: HMAC-SHA512(timestamp + "-" + nonce, key) 的 hex
  ({String timestamp, String nonce, String signature}) generateSignature({
    int timeDeltaFromServer = 0,
  }) {
    final timestampMs =
        DateTime.now().millisecondsSinceEpoch + timeDeltaFromServer;
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
  /// 1. 把 data 和 params 都扁平化合并到同一个 {key: [values]}（module-level n）
  /// 2. 若合并后仍为空，用 authToken 作为 Authorization 兜底
  /// 3. 按字典序排序 key
  /// 4. 拼成 key=value 格式（无分隔符），values 数组内部也排序
  /// 5. HMAC-SHA256(序列化字符串, "zhxintd201020301")，转大写
  String generateZhxhSign(
    Map<String, dynamic>? data,
    Map<String, dynamic>? params, {
    String? authToken,
  }) {
    final flat = <String, List<String>>{};
    if (data != null) {
      _flatten(data, flat);
    }
    if (params != null) {
      _flatten(params, flat);
    }
    if (flat.isEmpty && authToken != null && authToken.isNotEmpty) {
      flat['Authorization'] = [authToken];
    }

    final keys = flat.keys.toList()..sort();
    final buffer = StringBuffer();
    for (final k in keys) {
      final values = flat[k]!;
      values.sort();
      if (values.isNotEmpty) {
        for (final v in values) {
          buffer.write('$k=$v');
        }
      } else {
        buffer.write('$k=');
      }
    }

    final hmac = Hmac(sha256, utf8.encode(_zhxhKey));
    final digest = hmac.convert(utf8.encode(buffer.toString()));
    return digest.toString().toUpperCase();
  }

  /// 递归把对象/数组扁平化到 {key: [values]}
  void _flatten(Object? value, Map<String, List<String>> out) {
    if (value == null) return;
    if (value is Map) {
      value.forEach((k, v) {
        final keyStr = k.toString();
        if (v is Map || v is List) {
          _flatten(v, out);
        } else {
          _addToBucket(out, keyStr, _stringify(v));
        }
      });
    } else if (value is List) {
      for (final item in value) {
        if (item is Map || item is List) {
          _flatten(item, out);
        }
      }
    }
  }

  void _addToBucket(Map<String, List<String>> out, String key, String value) {
    final list = out.putIfAbsent(key, () => <String>[]);
    list.add(value);
  }

  String _stringify(Object? v) {
    if (v == null) return 'null';
    if (v is String) return v;
    if (v is bool) return v.toString();
    if (v is num) return v.toString();
    return v.toString();
  }

  /// 生成 26 字符随机 nonce
  String _generateNonce() {
    return _randomBase36(13) + _randomBase36(13);
  }

  String _randomBase36(int n) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final buf = StringBuffer();
    for (int i = 0; i < n; i++) {
      buf.write(chars[_random.nextInt(chars.length)]);
    }
    return buf.toString();
  }

  /// 构造 scjx2 API 所需的所有签名请求头
  ///
  /// 返回的 Map 包含：
  /// - nonce / timestamp / signature: HMAC-SHA512 签名
  /// - zhxhsign: HMAC-SHA256 签名
  /// - random: 当前时间戳
  /// - currentRoutePath: 前端路由路径（**必传**，不同模块不同）
  /// - MenuId: 可选
  Map<String, String> buildHeaders({
    Map<String, dynamic>? data,
    Map<String, dynamic>? params,
    String? menuId,
    String? authorization,
    required String currentRoutePath,
  }) {
    final sig = generateSignature();
    final zhxh = generateZhxhSign(
      data,
      params,
      authToken: authorization,
    );
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
