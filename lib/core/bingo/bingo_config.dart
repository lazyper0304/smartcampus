/// Bingo 后端（宜宾学院智慧校园代理服务）全局配置。
///
/// 单一来源：所有模块的接口 baseUrl、token 存储 key、超时均取自此处。
/// 迁移自 `E:/project/YibinApp/Flutter`（权威实现见
/// `YibinApp/Flutter/lib/core/constants/app_constants.dart`），
/// 注意 `FLUTTER_SERVER_API.md` 中写的 `v2.bingo.yaooa.cn` 已过时，
/// 现网为 `new.bingo.yaooa.cn`（见 YibinApp CHANGELOG 2026-09-27）。
library;

class BingoConfig {
  BingoConfig._();

  /// API 根地址（含 `/api/v1` 前缀，勿重复拼接）
  static const String baseUrl = 'https://new.bingo.yaooa.cn/api/v1';

  /// 连接超时
  static const Duration connectTimeout = Duration(seconds: 15);

  /// 接收超时
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// 附件下载超时（大文件）
  static const Duration downloadTimeout = Duration(minutes: 2);

  // ==================== 本地存储 key ====================

  /// 访问令牌（Header: `Authorization: Bearer {token}`）
  static const String keyAccessToken = 'bingo_access_token';

  /// 刷新令牌
  static const String keyRefreshToken = 'bingo_refresh_token';

  /// 登录态绑定的 API 根（多环境 / 换服隔离）
  static const String keySessionApiBase = 'bingo_session_api_base';

  /// 当前登录的学号（Bingo 侧 user.school_id）
  static const String keySchoolId = 'bingo_school_id';

  /// 缓存的用户信息 JSON
  static const String keyUserInfo = 'bingo_user_info';

  // ==================== 缓存 key ====================

  static const String keySemesterInfo = 'bingo_semester_info';
  static const String keyCourseSnapshot = 'bingo_course_snapshot';
  static const String keyGradeCache = 'bingo_grade_cache';
  static const String keyEvaluationCache = 'bingo_evaluation_cache';
  static const String keyErkeCache = 'bingo_erke_cache';

  // ==================== 业务码 ====================

  /// 业务成功码
  static const int codeOk = 0;

  /// 通用业务失败码
  static const int codeRequestFailed = 20000;

  /// 需要图形验证码（登录失败时后端下发 `captcha_id` / `captcha_image`）
  static const int codeCaptchaRequired = 20010;

  /// 验证码请求过于频繁（单 IP 15s 内超过 30 次）
  static const int codeCaptchaTooFrequent = 20022;

  /// 认证失败
  static const int codeUnauthorized = 40100;

  /// 拼接相对路径为绝对 URI。[path] 需以 `/` 开头（相对 `/api/v1`）。
  static Uri uri(String path, [Map<String, dynamic>? query]) {
    final cleaned = path.startsWith('/') ? path : '/$path';
    final base = Uri.parse(baseUrl);
    return base.replace(
      path: '${base.path}$cleaned',
      queryParameters: query == null || query.isEmpty
          ? null
          : query.map((k, v) => MapEntry(k, '$v')),
    );
  }
}