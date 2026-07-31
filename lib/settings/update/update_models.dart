/// 更新检查 / 日志模块的数据模型。
///
/// 这些模型与 UI 解耦，由 [UpdateService] 产出，供对话框或任意页面消费。

library;

/// 一次「检查更新」的结果。
class UpdateCheckResult {
  /// 当前版本是否为最新（false 表示有新版本可用）。
  final bool hasUpdate;

  /// 远端最新 release 的 tag（可能含前导 v）。
  final String latestTag;

  /// 去除前导 v 后的最新版本号，如 1.2.0。
  final String latestVersion;

  /// 最新 release 的更新说明（markdown 文本）。
  final String releaseNotes;

  /// 推荐下载地址：优先 APK asset，否则回退到 release 下载页。
  final String downloadUrl;

  const UpdateCheckResult({
    required this.hasUpdate,
    required this.latestTag,
    required this.latestVersion,
    required this.releaseNotes,
    required this.downloadUrl,
  });
}

/// 单个 release 的概要信息，用于更新日志列表。
class ReleaseInfo {
  /// release tag，如 v1.1.2。
  final String tagName;

  /// release 正文（更新说明）。
  final String body;

  /// 发布时间，ISO8601 字符串。
  final String publishedAt;

  const ReleaseInfo({
    required this.tagName,
    required this.body,
    required this.publishedAt,
  });
}
