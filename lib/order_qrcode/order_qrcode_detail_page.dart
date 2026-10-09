import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/responsive.dart';
import '../core/simple_page.dart';
import '../core/theme_utils.dart';
import 'order_qrcode_model.dart';
import 'order_qrcode_service.dart';
import 'widgets/order_qrcode_widgets.dart';

/// 点餐码详情页：二维码 + 商家信息 + 评价。
///
/// 参考实现 `order_qrcode_detail_page.dart`（BingoApp）。差异同上：
/// 无 Riverpod / 无 easy_localization / 页面壳用 [SimplePage]。
class OrderQrcodeDetailPage extends StatefulWidget {
  const OrderQrcodeDetailPage({super.key, required this.item});

  final OrderQRCode item;

  @override
  State<OrderQrcodeDetailPage> createState() => _OrderQrcodeDetailPageState();
}

class _OrderQrcodeDetailPageState extends State<OrderQrcodeDetailPage> {
  final OrderQrcodeService _service = OrderQrcodeService.instance;

  List<OrderQRCodeReview> _reviews = const [];
  OrderQRCodeReview? _myReview;
  bool _loadingReviews = true;
  bool _editingReview = false;
  int _rating = 5;
  bool _submittingReview = false;
  final TextEditingController _reviewCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  @override
  void dispose() {
    _reviewCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    if (!mounted) return;
    setState(() => _loadingReviews = true);
    try {
      final results = await Future.wait([
        _service.listReviews(widget.item.id),
        _service.myReview(widget.item.id),
      ]);
      if (!mounted) return;
      setState(() {
        _reviews = results[0] as List<OrderQRCodeReview>;
        _myReview = results[1] as OrderQRCodeReview?;
        _loadingReviews = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingReviews = false);
    }
  }

  /// 我的评价置顶
  List<OrderQRCodeReview> get _displayReviews {
    final my = _myReview;
    if (my == null) return _reviews;
    return [my, ..._reviews.where((r) => r.id != my.id)];
  }

  void _startEditReview() {
    final my = _myReview;
    setState(() {
      _editingReview = true;
      _rating = my?.rating ?? 5;
      _reviewCtrl.text = my?.content ?? '';
    });
  }

  Future<void> _submitReview() async {
    final content = _reviewCtrl.text.trim();
    if (content.isEmpty) {
      await _alert('请填写评价内容');
      return;
    }
    setState(() => _submittingReview = true);
    try {
      await _service.submitReview(
        widget.item.id,
        rating: _rating,
        content: content,
      );
      if (!mounted) return;
      setState(() => _editingReview = false);
      await _alert('评价已提交');
      await _loadReviews();
    } catch (e) {
      if (mounted) {
        await _alert('评价提交失败：${e.toString().replaceFirst('Exception: ', '')}');
      }
    } finally {
      if (mounted) setState(() => _submittingReview = false);
    }
  }

  Future<void> _toggleLike(OrderQRCodeReview review) async {
    try {
      await _service.toggleReviewLike(review.id);
      if (!mounted) return;
      await _loadReviews();
    } catch (_) {}
  }

  Future<void> _alert(String msg) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        content: Text(msg),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final topPad = MediaQuery.viewPaddingOf(context).top + 44;
    final bottomInset = systemBottomInset(context);

    return SimplePage(
      child: DefaultTextStyle(
        style: TextStyle(
          decoration: TextDecoration.none,
          color: textPrimary(context),
        ),
        child: ListView(
          padding: EdgeInsets.fromLTRB(0, topPad, 0, 40 + bottomInset),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Icon(CupertinoIcons.back, size: 24),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.shopName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: textPrimary(context),
                        letterSpacing: -0.4,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // ── 二维码卡 ──
            OrderPanel(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                children: [
                  if (item.shopCategory.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: kOrderRatingColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.shopCategory,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kOrderRatingColor,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (item.reviewCount > 0) ...[
                    Text(
                      item.avgRating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: kOrderRatingColor,
                        height: 1,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OrderStars(rating: item.avgRating, size: 16, gap: 3),
                    const SizedBox(height: 6),
                    Text(
                      '${item.reviewCount} 条评价',
                      style: TextStyle(
                        fontSize: 13,
                        color: textSecondary(context),
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (item.qrContent.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: item.qrContent,
                        size: 220,
                        backgroundColor: Colors.white,
                      ),
                    )
                  else
                    Text(
                      '该点餐码暂无二维码内容',
                      style: TextStyle(
                        fontSize: 14,
                        color: textSecondary(context),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    '用微信/支付宝扫一扫即可点餐',
                    style: TextStyle(
                      fontSize: 13,
                      color: textSecondary(context),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // ── 信息卡 ──
            _InfoPanel(item: item),
            const SizedBox(height: 12),
            // ── 评价区 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Row(
                children: [
                  Text(
                    '评价',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: textPrimary(context),
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const Spacer(),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    color: kOrderRatingColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                    onPressed: _startEditReview,
                    child: Text(
                      _myReview == null ? '写评价' : '编辑我的评价',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: kOrderRatingColor,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_editingReview)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ReviewEditor(
                  rating: _rating,
                  controller: _reviewCtrl,
                  submitting: _submittingReview,
                  onRating: (r) => setState(() => _rating = r),
                  onCancel: () => setState(() => _editingReview = false),
                  onSubmit: _submitReview,
                ),
              ),
            if (_loadingReviews)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CupertinoActivityIndicator()),
              )
            else if (_displayReviews.isEmpty)
              OrderPanel(
                child: Center(
                  child: Text(
                    '还没有评价，快来抢沙发',
                    style: TextStyle(
                      color: textSecondary(context),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              )
            else
              for (final r in _displayReviews)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ReviewTile(
                    review: r,
                    onLike: () => _toggleLike(r),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// 商家信息（上传者 / 校区 / 位置 / 说明）
class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.item});

  final OrderQRCode item;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('上传者', item.uploaderName.isEmpty ? '匿名' : item.uploaderName),
      if (item.campus.isNotEmpty) ('校区', item.campus),
      if (item.location.isNotEmpty) ('位置', item.location),
      if (item.description.isNotEmpty) ('说明', item.description),
    ];

    return OrderSettingsGroup(
      children: [
        for (var i = 0; i < rows.length; i++)
          if (i == 0 && item.uploaderAvatar.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 84,
                    child: Text(
                      rows[i].$1,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: textSecondary(context),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            rows[i].$2,
                            textAlign: TextAlign.right,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.35,
                              color: textPrimary(context),
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ClipOval(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: _AuthImage(url: item.uploaderAvatar),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            OrderInfoRow(label: rows[i].$1, value: rows[i].$2),
      ],
    );
  }
}

/// 带 Bearer 鉴权的头像/图片（Bingo 媒体资源需 Header 鉴权）
class _AuthImage extends StatelessWidget {
  const _AuthImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      httpHeaders: orderMediaHeaders(),
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(color: textHint(context).withValues(alpha: 0.15)),
      errorWidget: (_, _, _) => Container(
        color: textHint(context).withValues(alpha: 0.15),
        child: Icon(CupertinoIcons.person_fill,
            size: 16, color: textSecondary(context)),
      ),
    );
  }
}

/// 评价编辑器（星级 + 文本）
class _ReviewEditor extends StatelessWidget {
  const _ReviewEditor({
    required this.rating,
    required this.controller,
    required this.submitting,
    required this.onRating,
    required this.onCancel,
    required this.onSubmit,
  });

  final int rating;
  final TextEditingController controller;
  final bool submitting;
  final ValueChanged<int> onRating;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return OrderPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: Size.zero,
                  onPressed: () => onRating(i),
                  child: Icon(
                    i <= rating
                        ? CupertinoIcons.star_fill
                        : CupertinoIcons.star,
                    color: kOrderRatingColor,
                    size: 30,
                  ),
                ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: textHint(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: CupertinoTextField(
              controller: controller,
              maxLines: 4,
              maxLength: 200,
              placeholder: '说说这家店的味道、出餐速度…',
              placeholderStyle: TextStyle(color: textHint(context)),
              style: TextStyle(color: textPrimary(context)),
              decoration: null,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CupertinoButton(onPressed: onCancel, child: const Text('取消')),
              CupertinoButton.filled(
                borderRadius: BorderRadius.circular(12),
                onPressed: submitting ? null : onSubmit,
                child: submitting
                    ? const CupertinoActivityIndicator()
                    : const Text('提交'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 单条评价
class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review, required this.onLike});

  final OrderQRCodeReview review;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    final primary = textPrimary(context);
    final secondary = textSecondary(context);
    final statusNote = review.status == 'pending'
        ? '审核中'
        : review.status == 'rejected'
            ? (review.rejectReason.isNotEmpty
                ? review.rejectReason
                : review.llmReason)
            : '';

    return OrderPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: review.userAvatar.isNotEmpty
                      ? _AuthImage(url: review.userAvatar)
                      : Container(
                          color: textHint(context).withValues(alpha: 0.15),
                          child: Icon(CupertinoIcons.person_fill,
                              color: secondary, size: 18),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.userName.isEmpty ? '匿名' : review.userName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: primary,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 2),
                    OrderStars(rating: review.rating.toDouble(), size: 12),
                  ],
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: onLike,
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.hand_thumbsup,
                      size: 16,
                      color: review.liked ? kOrderRatingColor : secondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${review.likeCount}',
                      style: TextStyle(
                        fontSize: 13,
                        color: secondary,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            review.content,
            style: TextStyle(
              fontSize: 15,
              color: primary,
              height: 1.4,
              decoration: TextDecoration.none,
            ),
          ),
          if (statusNote.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                statusNote,
                style: const TextStyle(
                  fontSize: 12,
                  color: kOrderRatingColor,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
