import 'dart:collection';

/// 内存数据缓存，TTL = 1 天
class DataCache {
  DataCache._();
  static final DataCache _instance = DataCache._();
  factory DataCache() => _instance;

  final _store = HashMap<String, _Entry>();

  static const _ttl = Duration(days: 1);

  /// 读取缓存，过期返回 null
  T? get<T>(String key) {
    final entry = _store[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.time) > _ttl) {
      _store.remove(key);
      return null;
    }
    return entry.data as T;
  }

  /// 写入缓存
  void set<T>(String key, T data) {
    _store[key] = _Entry(data, DateTime.now());
  }

  /// 清除指定 key 的缓存
  void invalidate(String key) {
    _store.remove(key);
  }

  /// 清除所有缓存
  void invalidateAll() {
    _store.clear();
  }
}

class _Entry {
  final dynamic data;
  final DateTime time;
  _Entry(this.data, this.time);
}
