import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/glass_style.dart';
import '../../core/theme_utils.dart';
import '../order_qrcode_model.dart';

/// 点餐码模块评级色（琥珀，与首页「电费」卡同色，属项目既有色板）
const Color kOrderRatingColor = Color(0xFFFFB020);

/// 点餐码卡片容器（实色 + 极淡描边 + 轻投影，项目统一实色卡风格）。
///
/// 参考实现 `order_qrcode_panel.dart`（BingoApp）。本项目无 `AppSurfaceColors`，
/// 统一走 `lib/core/glass_style.dart` 的 `solidSurface/solidHairline/solidShadow`。
class OrderPanel extends StatelessWidget {
  const OrderPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
    this.borderRadius = 18,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double borderRadius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final panel = Container(
      decoration: BoxDecoration(
        color: solidSurface(context),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: solidHairline(context), width: 1),
        boxShadow: solidShadow(context),
      ),
      child: Padding(padding: padding, child: child),
    );
    return Padding(
      padding: margin,
      // ⚠️ 列表项不用 IosCard/Clickable：其内部 Stack(fit: loose) 在
      // ListView 中会收缩导致点击失效 + "RenderBox was not laid out"。
      child: onTap == null
          ? panel
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: panel,
            ),
    );
  }
}

/// 五星评分（只读展示）
class OrderStars extends StatelessWidget {
  const OrderStars({super.key, required this.rating, this.size = 12, this.gap = 1});

  final double rating;
  final double size;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final rounded = rating.round().clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++) ...[
          if (i > 1) SizedBox(width: gap),
          Icon(
            i <= rounded ? CupertinoIcons.star_fill : CupertinoIcons.star,
            size: size,
            color: i <= rounded ? kOrderRatingColor : textHint(context),
          ),
        ],
      ],
    );
  }
}

/// 列表商家卡片：店名 + 评分/类别，右侧箭头。
///
/// 与参考实现一致：地点与上传者**不在列表展示**（只在详情页）。
class OrderShopTile extends StatelessWidget {
  const OrderShopTile({super.key, required this.item, required this.onTap});

  final OrderQRCode item;
  final VoidCallback onTap;

  static const double paddingH = 16;
  static const double paddingV = 18;

  @override
  Widget build(BuildContext context) {
    final primary = textPrimary(context);
    final secondary = textSecondary(context);
    final hasReviews = item.reviewCount > 0;

    final spans = <InlineSpan>[
      if (hasReviews) ...[
        TextSpan(
          text: item.avgRating.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 14,
            height: 1.25,
            fontWeight: FontWeight.w600,
            color: kOrderRatingColor,
            decoration: TextDecoration.none,
          ),
        ),
        TextSpan(text: '  ', style: TextStyle(fontSize: 14, color: secondary)),
        TextSpan(
          text: '${item.reviewCount} 条评价',
          style: TextStyle(fontSize: 14, height: 1.25, color: secondary),
        ),
      ] else
        TextSpan(
          text: '暂无评价',
          style: TextStyle(fontSize: 14, height: 1.25, color: secondary),
        ),
      if (item.shopCategory.isNotEmpty) ...[
        TextSpan(text: '  ', style: TextStyle(fontSize: 14, color: secondary)),
        TextSpan(
          text: item.shopCategory,
          style: TextStyle(fontSize: 14, height: 1.25, color: secondary),
        ),
      ],
    ];

    return OrderPanel(
      padding: const EdgeInsets.symmetric(horizontal: paddingH, vertical: paddingV),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.shopName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.22,
                    letterSpacing: -0.3,
                    color: primary,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 10),
                Text.rich(
                  TextSpan(children: spans),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(CupertinoIcons.chevron_right, size: 16, color: secondary),
        ],
      ),
    );
  }
}

/// 校区分组标题（列表按校区分组时）
class OrderGroupHeader extends StatelessWidget {
  const OrderGroupHeader({super.key, required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final secondary = textSecondary(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: kOrderRatingColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: textPrimary(context),
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: secondary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: secondary,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 空态
class OrderEmptyState extends StatelessWidget {
  const OrderEmptyState({super.key, this.hint = '还没有人分享点餐码，快来上传第一个吧'});

  final String hint;

  @override
  Widget build(BuildContext context) {
    final primary = textPrimary(context);
    final secondary = textSecondary(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 72),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: kOrderRatingColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(CupertinoIcons.qrcode,
                size: 36, color: kOrderRatingColor),
          ),
          const SizedBox(height: 20),
          Text(
            '暂无点餐码',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: primary,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: secondary,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

/// 分组标题（设置页风格小节标题）
class OrderSectionHeader extends StatelessWidget {
  const OrderSectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 20, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: textSecondary(context),
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

/// 设置风格分组容器（多行共用一张卡）
class OrderSettingsGroup extends StatelessWidget {
  const OrderSettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final hairline = solidHairline(context);
    final panel = Container(
      decoration: BoxDecoration(
        color: solidSurface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: hairline, width: 1),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(height: 1, thickness: 0, color: hairline, indent: 16),
            children[i],
          ],
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: panel,
    );
  }
}

/// 可点击行（左标题 + 右值 + 箭头）
class OrderLinkRow extends StatelessWidget {
  const OrderLinkRow({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.valueColor,
    this.showChevron = true,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final Color? valueColor;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final primary = textPrimary(context);
    final secondary = textSecondary(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: primary,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  color: valueColor ?? secondary,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            if (showChevron) ...[
              const SizedBox(width: 6),
              Icon(CupertinoIcons.chevron_right, size: 15, color: secondary),
            ],
          ],
        ),
      ),
    );
  }
}

/// 只读信息行（左标题 + 右值，可换行）
class OrderInfoRow extends StatelessWidget {
  const OrderInfoRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final primary = textPrimary(context);
    final secondary = textSecondary(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: secondary,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 15,
                height: 1.35,
                color: primary,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 分组内的动作行（居中，如「提交」）
class OrderActionRow extends StatelessWidget {
  const OrderActionRow({
    super.key,
    required this.label,
    required this.onTap,
    this.loading = false,
    this.color,
  });

  final String label;
  final VoidCallback onTap;
  final bool loading;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? kOrderRatingColor;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: loading ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CupertinoActivityIndicator(),
                )
              : Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: accent,
                    decoration: TextDecoration.none,
                  ),
                ),
        ),
      ),
    );
  }
}
