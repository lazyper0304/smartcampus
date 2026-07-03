import 'dart:convert';
import 'dart:io';
import 'dart:async';

/// 轻量级本地存储，使用 JSON 文件读写
/// 避免引入 shared_preferences 的 Kotlin 编译问题
class LocalStorage {
  static const String _fileName = 'smartcampus_data.json';
  static Map<String, dynamic>? _cache;
  static Completer<void>? _initCompleter;
  static String? _filePath;

  /// 初始化存储文件路径
  static Future<String> _getFilePath() async {
    if (_filePath != null) return _filePath!;

    // 优先使用应用数据目录
    if (Platform.isAndroid) {
      // Android: /data/data/.../files/
      final dir = Directory('/data/data/com.smartcampus/files');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _filePath = '${dir.path}/$_fileName';
    } else if (Platform.isWindows) {
      final dir = Directory('${Platform.environment['APPDATA'] ?? '.'}/smartcampus');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _filePath = '${dir.path}/$_fileName';
    } else {
      _filePath = '/tmp/$_fileName';
    }
    return _filePath!;
  }

  /// 读取所有数据
  static Future<Map<String, dynamic>> _readAll() async {
    if (_cache != null) return _cache!;
    if (_initCompleter != null) {
      await _initCompleter!.future;
      return _cache!;
    }

    _initCompleter = Completer<void>();
    try {
      final path = await _getFilePath();
      final file = File(path);
      if (await file.exists()) {
        final content = await file.readAsString();
        _cache = jsonDecode(content) as Map<String, dynamic>;
      } else {
        _cache = {};
      }
    } catch (_) {
      _cache = {};
    }
    _initCompleter!.complete();
    return _cache!;
  }

  /// _写入所有数据
  static Future<void> _writeAll() async {
    if (_cache == null) return;
    try {
      final path = await _getFilePath();
      final file = File(path);
      await file.writeAsString(jsonEncode(_cache));
    } catch (_) {
      // 写入失败忽略
    }
  }

  /// 读取字符串
  static Future<String?> getString(String key) async {
    final data = await _readAll();
    return data[key]?.toString();
  }

  /// 读取布尔值
  static Future<bool> getBool(String key) async {
    final data = await _readAll();
    return data[key] == true;
  }

  /// 写入字符串
  static Future<void> setString(String key, String value) async {
    await _readAll();
    _cache![key] = value;
    await _writeAll();
  }

  /// 写入布尔值
  static Future<void> setBool(String key, bool value) async {
    await _readAll();
    _cache![key] = value;
    await _writeAll();
  }

  /// 删除键
  static Future<void> remove(String key) async {
    await _readAll();
    _cache!.remove(key);
    await _writeAll();
  }
}
