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
  /// 1. 把 data 和 params 都扁平化合并到同一个 {key: [values]}（module-level n）
  /// 2. 若合并后仍为空，用 authToken 作为 Authorization 兜底
  /// 3. 按字典序排序 key
  /// 4. 拼成 key=value 格式（无分隔符），values 数组内部也排序
  /// 5. HMAC-SHA256(序列化字符串, "zhxintd201020301")，转大写
  ///
  /// 关键发现：`u()` 内部 `n = {}` 是对 module-level n 的赋值（非 var 声明），
  /// `m()` 写的是 module-level n，所以 data 和 params 会合并到同一个 map。
  String generateZhxhSign(
    Map<String, dynamic>? data,
    Map<String, dynamic>? params, {
    String? authToken,
  }) {
    // 1. 扁平化合并到 {key: [values]}（同 2fd1 模块 module-level n）
    final flat = <String, List<String>>{};
    if (data != null) {
      _flatten(data, flat);
    }
    if (params != null) {
      _flatten(params, flat);
    }
    // 2. 兜底：若 data 和 params 都为空，用 Authorization 字段
    if (flat.isEmpty && authToken != null && authToken.isNotEmpty) {
      flat['Authorization'] = [authToken];
    }
    // 3. 排序 key
    final keys = flat.keys.toList()..sort();
    // 4. 拼成 key=value 格式
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
    // 5. HMAC-SHA256
    final hmac = Hmac(sha256, utf8.encode(_zhxhKey));
    final digest = hmac.convert(utf8.encode(buffer.toString()));
    return digest.toString().toUpperCase();
  }

  /// 递归把对象/数组扁平化到 {key: [values]}
  ///
  /// 简单值（string/number/bool/null）进入 list
  /// 嵌套对象：递归处理，prefix 路径（但前端实际不加点号分隔，直接用 leaf key）
  /// 实践中 RACE API 调用都用扁平对象，无需关心
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
        // 数组里的简单值不直接进 out（前端 m 数组分支用 prefix，调用处不传）
      }
    }
    // 顶层简单值不会到达这里
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
    Map<String, dynamic>? data,
    Map<String, dynamic>? params,
    String? menuId,
    String? authorization,
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
