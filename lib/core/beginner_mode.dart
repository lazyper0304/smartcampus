import 'local_storage.dart';

/// 新生模式全局状态。
///
/// 适用于已录入智慧校园、但班级等个人信息暂未录入的账号。
/// 该模式下登录成功后跳过个人信息获取（不进入 FetchInfoPage 阻塞获取），
/// 其余与会话、SSO、功能入口完全一致。个人信息待学校录入后可正常获取。
///
/// 与 [GuestMode] 区别：新生模式仍为真实账号登录（有账号密码、有会话），
/// 仅暂缓个人信息拉取；游客模式则无账号、仅可用免登录功能。
class BeginnerMode {
  BeginnerMode._();

  static const String _key = 'beginner_mode';

  /// 当前是否处于新生模式（内存态，启动时通过 [load] 恢复）
  static bool active = false;

  /// 从本地存储恢复新生模式标记
  static Future<void> load() async {
    active = await LocalStorage.getBool(_key);
  }

  /// 进入新生模式并持久化
  static Future<void> enter() async {
    active = true;
    await LocalStorage.setBool(_key, true);
  }

  /// 退出新生模式并持久化（正常补录个人信息 / 退出登录 / 切换账号时调用）
  static Future<void> exit() async {
    active = false;
    await LocalStorage.setBool(_key, false);
  }
}
