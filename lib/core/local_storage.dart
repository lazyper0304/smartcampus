import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:path_provider/path_provider.dart';

/// 轻量级本地存储，使用 JSON 文件读写
class LocalStorage {
  static const String _fileName = 'smartcampus_data.json';
  static Map<String, dynamic>? _cache;
  static Completer<void>? _initCompleter;
  static String? _filePath;

  /// 获取应用文档目录下的存储文件路径
  static Future<String> _getFilePath() async {
    if (_filePath != null) return _filePath!;

    try {
      final dir = await getApplicationDocumentsDirectory();
      _filePath = '${dir.path}/$_fileName';
    } catch (_) {
      // 回退到临时目录
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

  static Future<void> _writeAll() async {
    if (_cache == null) return;
    try {
      final path = await _getFilePath();
      final file = File(path);
      await file.writeAsString(jsonEncode(_cache));
    } catch (_) {}
  }

  static Future<String?> getString(String key) async {
    final data = await _readAll();
    return data[key]?.toString();
  }

  static Future<bool> getBool(String key) async {
    final data = await _readAll();
    return data[key] == true;
  }

  static Future<void> setString(String key, String value) async {
    await _readAll();
    _cache![key] = value;
    await _writeAll();
  }

  static Future<void> setBool(String key, bool value) async {
    await _readAll();
    _cache![key] = value;
    await _writeAll();
  }

  static Future<void> remove(String key) async {
    await _readAll();
    _cache!.remove(key);
    await _writeAll();
  }
}
