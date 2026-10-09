import '../core/bingo/bingo_client.dart';
import 'order_qrcode_model.dart';

/// 点餐码服务（经 Bingo 后端代理 `/order-qrcode/*`）。
///
/// 参考实现：`E:/project/YibinApp/Flutter/lib/features/apps/order_qrcode/data/order_qrcode_api.dart`。
/// 本项目沿用既有 [BingoClient]（自动注入 Bearer token、401 单飞刷新），
/// 故不引入 dio；列表壳为 `{code,message,data:{items:[...]}}`。
class OrderQrcodeService {
  OrderQrcodeService._();
  static final OrderQrcodeService instance = OrderQrcodeService._();

  final BingoClient _client = BingoClient.instance;

  /// 点餐码列表（校区 / 分类 / 关键字三重筛选，空串表示不限）
  Future<List<OrderQRCode>> list({
    String campus = '',
    String category = '',
    String q = '',
  }) async {
    final data = await _client.getMap('/order-qrcode/list', query: {
      if (campus.isNotEmpty) 'campus': campus,
      if (category.isNotEmpty) 'category': category,
      if (q.isNotEmpty) 'q': q,
    });
    return _items(data, OrderQRCode.fromJson);
  }

  /// 校区分组（含每校区条数）
  Future<List<OrderCampusGroup>> campuses() async {
    final data = await _client.getMap('/order-qrcode/campuses');
    return _items(data, OrderCampusGroup.fromJson);
  }

  /// 分类分组（含每分类条数）
  Future<List<OrderCategoryGroup>> categories() async {
    final data = await _client.getMap('/order-qrcode/categories');
    return _items(data, OrderCategoryGroup.fromJson);
  }

  /// 我上传的点餐码
  Future<List<OrderQRCode>> myUploads() async {
    final data = await _client.getMap('/order-qrcode/my');
    return _items(data, OrderQRCode.fromJson);
  }

  /// 二维码查重（提交前/扫码后都调一次）
  Future<OrderQRCodeCheckResult> check(String qrContent) async {
    final data = await _client.getMap(
      '/order-qrcode/check',
      query: {'qr_content': qrContent},
    );
    return OrderQRCodeCheckResult.fromJson(data);
  }

  /// 提交点餐码
  Future<void> submit({
    required String campus,
    required String shopName,
    String shopCategory = '',
    String location = '',
    required String qrContent,
    String qrType = '',
    String description = '',
  }) async {
    await _client.postMap('/order-qrcode/submit', body: {
      'campus': campus,
      'shop_name': shopName,
      if (shopCategory.isNotEmpty) 'shop_category': shopCategory,
      if (location.isNotEmpty) 'location': location,
      'qr_content': qrContent,
      if (qrType.isNotEmpty) 'qr_type': qrType,
      if (description.isNotEmpty) 'description': description,
    });
  }

  /// 某点餐码的评价列表
  Future<List<OrderQRCodeReview>> listReviews(int qrcodeId) async {
    final data = await _client.getMap('/order-qrcode/$qrcodeId/reviews');
    return _items(data, OrderQRCodeReview.fromJson);
  }

  /// 我的评价（没有则 null）
  Future<OrderQRCodeReview?> myReview(int qrcodeId) async {
    final data = await _client.getMap('/order-qrcode/$qrcodeId/my-review');
    final raw = data['item'];
    if (raw is! Map<String, dynamic>) return null;
    return OrderQRCodeReview.fromJson(raw);
  }

  /// 发表 / 更新评价
  Future<void> submitReview(
    int qrcodeId, {
    required int rating,
    required String content,
  }) async {
    await _client.postMap('/order-qrcode/$qrcodeId/reviews', body: {
      'rating': rating,
      'content': content,
      'platform': 'app',
    });
  }

  /// 评价点赞 / 取消点赞
  Future<void> toggleReviewLike(int reviewId) async {
    await _client.postMap('/order-qrcode/reviews/$reviewId/like');
  }

  List<T> _items<T>(
    Map<String, dynamic> data,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final raw = data['items'];
    if (raw is! List) return <T>[];
    return raw
        .map((e) => fromJson(e is Map<String, dynamic>
            ? e
            : Map<String, dynamic>.from(e as Map)))
        .toList(growable: false);
  }
}
