import 'local_storage.dart';

/// 游客模式全局状态。
///
/// 游客模式下无账号密码，仅可使用无需登录的功能；
/// 需登录的功能入口（课程表、全校课表、成绩查询、考试安排、学业完成、
/// 综合素质、教材查询、学科竞赛、第二课堂）会被拦截并引导登录。
class GuestMode {
  GuestMode._();

  static const String _key = 'guest_mode';

  /// 当前是否处于游客模式（内存态，启动时通过 [load] 恢复）
  static bool active = false;

  /// 从本地存储恢复游客模式标记
  static Future<void> load() async {
    active = await LocalStorage.getBool(_key);
  }

  /// 进入游客模式并持久化
  static Future<void> enter() async {
    active = true;
    await LocalStorage.setBool(_key, true);
  }

  /// 退出游客模式并持久化（登录成功 / 前往登录页时调用）
  static Future<void> exit() async {
    active = false;
    await LocalStorage.setBool(_key, false);
  }
}
