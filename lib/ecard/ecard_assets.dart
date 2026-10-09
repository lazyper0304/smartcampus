/// 智能卡模块静态资源路径。
///
/// 对应 `assets/images/ecard/`，需在 `pubspec.yaml` 的 `assets:` 中声明
/// （本项目不使用目录通配，必须逐条列出）。
abstract final class EcardAssets {
  /// 内置默认卡面（服务端未下发或下载失败时回退）
  static const String defaultCardFace = 'assets/images/ecard/default_card_face.webp';
}