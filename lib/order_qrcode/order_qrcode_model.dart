/// 点餐码数据模型。
///
/// 字段对齐 `YibinApp/Flutter/lib/features/apps/order_qrcode/data/order_qrcode_model.dart`
/// （Bingo 后端 `/order-qrcode/*`，下划线键名）。
library;

import '../core/bingo/bingo_client.dart';
import '../core/bingo/bingo_config.dart';

/// 商家点餐码条目
class OrderQRCode {
  const OrderQRCode({
    required this.id,
    required this.campus,
    required this.shopName,
    required this.shopCategory,
    required this.location,
    required this.qrContent,
    required this.qrType,
    required this.description,
    required this.uploaderName,
    required this.uploaderAvatar,
    required this.status,
    required this.rejectReason,
    required this.avgRating,
    required this.reviewCount,
    required this.createdAt,
  });

  final int id;
  final String campus;
  final String shopName;
  final String shopCategory;
  final String location;

  /// 二维码原始内容（扫码下单用的字符串/链接）
  final String qrContent;

  /// 二维码类型：`url` / `wechat_mini` / `wechat_app` / `alipay` / `text`
  final String qrType;
  final String description;
  final String uploaderName;
  final String uploaderAvatar;

  /// `pending` / `approved` / `rejected`
  final String status;
  final String rejectReason;
  final double avgRating;
  final int reviewCount;
  final String createdAt;

  factory OrderQRCode.fromJson(Map<String, dynamic> j) => OrderQRCode(
        id: (j['id'] as num?)?.toInt() ?? 0,
        campus: j['campus'] as String? ?? '',
        shopName: j['shop_name'] as String? ?? '',
        shopCategory: j['shop_category'] as String? ?? '',
        location: j['location'] as String? ?? '',
        qrContent: j['qr_content'] as String? ?? '',
        qrType: j['qr_type'] as String? ?? 'text',
        description: j['description'] as String? ?? '',
        uploaderName: j['uploader_name'] as String? ?? '',
        uploaderAvatar: resolveOrderMediaUrl(j['uploader_avatar']?.toString()),
        status: j['status'] as String? ?? '',
        rejectReason: j['reject_reason'] as String? ?? '',
        avgRating: (j['avg_rating'] as num?)?.toDouble() ?? 0,
        reviewCount: (j['review_count'] as num?)?.toInt() ?? 0,
        createdAt: j['created_at']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'campus': campus,
        'shop_name': shopName,
        'shop_category': shopCategory,
        'location': location,
        'qr_content': qrContent,
        'qr_type': qrType,
        'description': description,
        'uploader_name': uploaderName,
        'uploader_avatar': uploaderAvatar,
        'status': status,
        'reject_reason': rejectReason,
        'avg_rating': avgRating,
        'review_count': reviewCount,
        'created_at': createdAt,
      };
}

/// 点餐码评价
class OrderQRCodeReview {
  const OrderQRCodeReview({
    required this.id,
    required this.rating,
    required this.content,
    required this.status,
    required this.rejectReason,
    required this.llmReason,
    required this.likeCount,
    required this.createdAt,
    required this.userName,
    required this.userAvatar,
    this.liked = false,
    this.imageUrls = const [],
  });

  final int id;
  final int rating;
  final String content;

  /// `approved` / `pending` / `rejected`（LLM 审核）
  final String status;
  final String rejectReason;
  final String llmReason;
  final int likeCount;
  final String createdAt;
  final String userName;
  final String userAvatar;
  final bool liked;
  final List<String> imageUrls;

  factory OrderQRCodeReview.fromJson(Map<String, dynamic> j) => OrderQRCodeReview(
        id: (j['id'] as num?)?.toInt() ?? 0,
        rating: (j['rating'] as num?)?.toInt() ?? 0,
        content: j['content'] as String? ?? '',
        status: j['status'] as String? ?? '',
        rejectReason: j['reject_reason'] as String? ?? '',
        llmReason: j['llm_reason'] as String? ?? '',
        likeCount: (j['like_count'] as num?)?.toInt() ?? 0,
        createdAt: j['created_at']?.toString() ?? '',
        userName: j['user_name'] as String? ?? '',
        userAvatar: resolveOrderMediaUrl(j['user_avatar']?.toString()),
        liked: j['liked'] == true,
        imageUrls: (j['image_urls'] as List<dynamic>? ?? const [])
            .map((e) => resolveOrderMediaUrl(e.toString()))
            .where((e) => e.isNotEmpty)
            .toList(growable: false),
      );
}

/// 校区分组（筛选器来源）
class OrderCampusGroup {
  const OrderCampusGroup({required this.campus, required this.count});
  final String campus;
  final int count;

  factory OrderCampusGroup.fromJson(Map<String, dynamic> j) => OrderCampusGroup(
        campus: j['campus'] as String? ?? '',
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

/// 分类分组（筛选器来源）
class OrderCategoryGroup {
  const OrderCategoryGroup({required this.category, required this.count});
  final String category;
  final int count;

  factory OrderCategoryGroup.fromJson(Map<String, dynamic> j) => OrderCategoryGroup(
        category: j['category'] as String? ?? '',
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

/// 二维码查重结果
class OrderQRCodeCheckResult {
  const OrderQRCodeCheckResult({
    required this.duplicate,
    this.status,
    this.shopName,
  });

  final bool duplicate;
  final String? status;
  final String? shopName;

  factory OrderQRCodeCheckResult.fromJson(Map<String, dynamic> j) => OrderQRCodeCheckResult(
        duplicate: j['duplicate'] == true,
        status: j['status'] as String?,
        shopName: j['shop_name'] as String?,
      );
}

/// 点餐码模块工具（校区 / 分类预设、二维码类型与状态文案）
abstract final class OrderQrcodeUtils {
  /// 校区预设（与 BingoApp `order_qrcode_utils.dart` 一致）
  static const campusPresets = ['临港校区', '江北A区', '江北B区'];

  /// 分类预设
  static const categoryPresets = ['正餐', '快餐', '面食', '小吃', '奶茶', '水果', '其他'];

  /// 识别二维码内容类型
  static String detectQrType(String content) {
    if (content.isEmpty) return 'text';
    if (content.startsWith('https://wxaurl.cn') ||
        content.startsWith('wxp://') ||
        content.startsWith('weixin://')) {
      return 'wechat_mini';
    }
    if (content.startsWith('https://mp.weixin.qq.com') ||
        content.startsWith('https://weixin.qq.com')) {
      return 'wechat_app';
    }
    if (content.startsWith('alipays://') ||
        content.startsWith('https://qr.alipay.com')) {
      return 'alipay';
    }
    if (content.startsWith('http://') || content.startsWith('https://')) return 'url';
    return 'text';
  }

  static String qrTypeLabel(String type) => switch (type) {
        'url' => '网页链接',
        'wechat_mini' => '微信小程序',
        'wechat_app' => '微信公众号',
        'alipay' => '支付宝',
        _ => '纯文本',
      };

  static String statusLabel(String status) => switch (status) {
        'pending' => '审核中',
        'approved' => '已通过',
        'rejected' => '未通过',
        _ => status.isEmpty ? '未知' : status,
      };

  /// 是否支持在外部浏览器/App 中打开（不是所有二维码都能直接 open）
  static bool canOpenExternally(String qrType) =>
      qrType == 'url' || qrType == 'wechat_app' || qrType == 'alipay';
}

/// 头像 / 评价图片：相对路径补全为绝对地址。
///
/// Bingo 后端对头像下发两种形态：完整 URL，或裸文件名（需拼到
/// `/api/v1/media/<name>`）。鉴权走 Header（见 [orderMediaHeaders]），
/// URL 本身不挂 token。
String resolveOrderMediaUrl(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  var s = raw.trim();
  if (!s.contains('://') && !s.startsWith('/')) {
    s = '/api/v1/media/${s.replaceFirst(RegExp(r'^/+'), '')}';
  }
  if (!s.startsWith('/')) return s;
  // ⚠️ 单一来源：媒体地址根就是 Bingo API 根（含 `/api/v1`），
  // 头像裸文件名会被补成 `/api/v1/media/<name>`。
  final base = Uri.parse(BingoConfig.baseUrl);
  final port = base.hasPort && base.port != 80 && base.port != 443 ? ':${base.port}' : '';
  return '${base.scheme}://${base.host}$port$s';
}

/// 受保护媒体（头像 / 评价图）请求头：带 Bearer token。
Map<String, String> orderMediaHeaders() {
  final token = BingoClient.accessToken;
  if (token == null || token.isEmpty) return const {};
  return {'Authorization': 'Bearer $token'};
}
