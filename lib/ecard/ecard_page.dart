import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/ios_kit.dart';
import '../core/simple_page.dart';
import '../core/theme_utils.dart';
import 'ecard_assets.dart';
import 'ecard_card_detail_page.dart';
import 'ecard_controller.dart';
import 'ecard_model.dart';
import 'ecard_transaction_aggregate.dart';
import 'ecard_transaction_detail_page.dart';
import 'widgets/ecard_balance_amount.dart';
import 'widgets/ecard_face_card.dart';

/// 校园一卡通（智能卡）主页面。
///
/// 参考实现：`E:/project/YibinApp/Flutter/lib/features/apps/ecard/presentation/ecard_page.dart`
/// 差异：本项目无 Riverpod（改`ListenableBuilder` + `ChangeNotifier`）、
/// 无 easy_localization（改硬编码中文）、页面壳用 [SimplePage] 而非
/// `AppPageScaffold`、图标用 Material `Icons.*` 而非 Lucide。
class EcardPage extends StatefulWidget {
  /// 进入页面时是否自动触发服务端同步。
  ///
  /// ⚠️ 默认**false**：手动刷新会带 `refresh=1`，后端随即进入同步态
  /// （`syncing: true`），客户端进入轮询，期间页面显示「同步中」。
  /// 首屏自动同步会让用户一进来就看到加载态，故改为按需触发。
  final bool autoRefresh;

  const EcardPage({super.key, this.autoRefresh = false});

  @override
  State<EcardPage> createState() => _EcardPageState();
}

class _EcardPageState extends State<EcardPage> {
  final EcardController _controller = EcardController();
  bool _loadMorePending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.load(manualRefresh: widget.autoRefresh);
      _controller.loadCardFaces();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openTransaction(List<EcardTransaction> items) {
    Navigator.of(context).push<void>(
      CupertinoPageRoute(
        builder: (_) => EcardTransactionDetailPage(items: items),
      ),
    );
  }

  void _openCardDetail() {
    Navigator.of(context).push<void>(
      // 传入共享 state：详情页切换卡面后，主页面能立即感知并刷新卡面
      CupertinoPageRoute(
        builder: (_) => EcardCardDetailPage(
          controller: _controller.shareWith(_controller.state),
        ),
      ),
    );
  }

  void _showTopUp() {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('充值'),
        content: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('请在微信中打开宜宾学院计划财务处公众号充值'),
        ),
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
    // ⚠️ 必须包 SimplePage（项目所有二级页的统一容器，自带 LiquidBackground
    // 背景层并随路由滑入）。裸 widget 会因缺少背景层而看起来「没反应」。
    return SimplePage(
      // ⚠️ 必须监听 `state`（EcardState 才是真正调用 notifyListeners 的对象），
      // 监听 `_controller` 收不到通知 → 页面永远停在首帧的加载态。
      child: ListenableBuilder(
        listenable: _controller.state,
        builder: (context, _) {
          final s = _controller.state;
          // ⚠️ 必须用 `viewPadding` 而非 `padding`：全局沉浸式下系统栏已隐藏，
          // `MediaQuery.padding.top` 恒为 0，用它会导致顶部留白失效、
          // 标题顶到屏幕边缘（甚至被刘海/挖孔遮挡）。
          final topPad = MediaQuery.viewPaddingOf(context).top + 44;
          Widget body;
          if (s.showBootstrapLoading) {
            body = Padding(
              padding: EdgeInsets.only(top: topPad),
              child: const Center(child: CupertinoActivityIndicator()),
            );
          } else if (s.loadError != null && !s.hasData) {
            body = _buildError(s.loadError!, topPad);
          } else {
            body = _buildContent(s);
          }
          // ⚠️ 全局文字装饰兜底：本页无 Material 祖先（SimplePage → LiquidBackground），
          // 部分场景会继承到带下划线的 DefaultTextStyle，使标题下方出现黄色下划线。
          // 参考工程亦用同样兜底（ecard_page.dart 的 DefaultTextStyle）。
          return DefaultTextStyle(
            style: TextStyle(
              decoration: TextDecoration.none,
              color: textPrimary(context),
            ),
            child: body,
          );
        },
      ),
    );
  }

  Widget _buildError(String msg, double topPad) {
    return Padding(
      padding: EdgeInsets.only(top: topPad),
      child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, size: 44, color: textHint(context)),
          const SizedBox(height: 12),
          Text(msg, style: TextStyle(fontSize: 14, color: textSecondary(context))),
          const SizedBox(height: 16),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            color: CupertinoColors.activeBlue.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            onPressed: () => _controller.load(),
            child: const Text('重试'),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildContent(EcardState s) {
    final ov = s.overview;
    if (ov == null) {
      return Center(
        child: Text('暂无一卡通数据',
            style: TextStyle(fontSize: 14, color: textSecondary(context))),
      );
    }

    // 购热水 5 分钟窗口合并
    final groups = groupEcardTransactions(s.transactions);

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.axis == Axis.vertical) _maybeLoadMore(s, n.metrics);
        return false;
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        // ⚠️ 顶部留出刘海/挖孔 + 标题栏高度：`SimplePage` 不提供 AppBar，
        // 留白不足时标题会顶到屏幕边缘。
        // ⚠️ 必须用 `viewPadding` 而非 `padding`：全局沉浸式下系统栏已隐藏，
        // `MediaQuery.padding.top` 恒为 0，用它会导致留白失效。
        padding: EdgeInsets.fromLTRB(
            16, MediaQuery.viewPaddingOf(context).top + 44, 16, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: Text('校园一卡通',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: textPrimary(context),
                        letterSpacing: -0.4,
                        // ⚠️ 显式关闭文字装饰：`SimplePage` → `LiquidBackground`
                        // 链路上可能给 DefaultTextStyle 带上 decoration，
                        // 导致标题下方出现黄色下划线（参考工程亦用此兜底）。
                        decoration: TextDecoration.none)),
              ),
              // 手动刷新：触发服务端真实同步（带 refresh=1）
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                onPressed: s.syncing ? null : () => _controller.load(manualRefresh: true),
                child: Row(
                  children: [
                    Icon(Icons.refresh_rounded,
                        size: 16, color: textSecondary(context)),
                    const SizedBox(width: 4),
                    Text('刷新',
                        style:
                            TextStyle(fontSize: 13, color: textSecondary(context))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildWalletFace(s),
          const SizedBox(height: 16),
          _buildBalancePanel(ov, s.syncing),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text('近期交易',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: textPrimary(context),
                    letterSpacing: -0.4,
                    decoration: TextDecoration.none)),
          ),
          if (groups.isEmpty)
            _buildEmptyCard()
          else
            _buildTransactionList(groups),
        ],
      ),
    );
  }

  /// 钱包卡面（含彩色光晕）
  Widget _buildWalletFace(EcardState s) {
    final display = s.cardFaces.displayMeta;
    final faceId = display?.id ?? 0;
    final md5 = display?.md5 ?? '';
    final filePath = s.cardFacePaths[faceId];
    return EcardFaceCard(
      // key 编码三元组，换面即强制重建（否则异步采样的光晕不会刷新）
      key: ValueKey('ecard-wallet-face-$faceId|$md5|${filePath ?? ''}'),
      faceId: faceId,
      faceImageMd5: md5,
      faceAssetPath: EcardAssets.defaultCardFace,
      faceFilePath: filePath,
    );
  }

  Widget _buildBalancePanel(EcardOverview ov, bool syncing) {
    final primary = textPrimary(context);
    final secondary = textSecondary(context);
    return IosCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text('余额',
                      style: TextStyle(fontSize: 15, color: secondary)),
                  if (syncing) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.sync_rounded, size: 13, color: secondary),
                    const SizedBox(width: 3),
                    Text('同步中',
                        style: TextStyle(fontSize: 11, color: secondary)),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              EcardBalanceAmount(amount: ov.balance, color: primary),
            ],
          ),
          const Spacer(),
          // 「卡片信息」入口：点余额区右侧的卡片图标进入（参考工程在导航栏 ⋯ 按钮）
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: CupertinoColors.activeBlue.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(22),
            onPressed: _openCardDetail,
            child: Text(
              '卡片信息',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.activeBlue),
            ),
          ),
          const SizedBox(width: 8),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            color: CupertinoColors.activeBlue.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(22),
            onPressed: _showTopUp,
            child: Text(
              '充值',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.activeBlue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(List<EcardTransactionGroup> groups) {
    final secondary = textSecondary(context);
    return IosCard(
      padding: EdgeInsets.zero,
      radius: 22,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < groups.length; i++) ...[
            if (i > 0) Divider(height: 0.5, thickness: 0.5, indent: 68,
                color: secondary.withValues(alpha: 0.25)),
            _buildTransactionRow(groups[i]),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildTransactionRow(EcardTransactionGroup group) {
    final primary = textPrimary(context);
    final secondary = textSecondary(context);
    final item = group.head;
    final subtitle = group.isMerged
        // 合并组显示笔数，避免用户以为丢了几笔
        ? '${_formatTransDate(item.transTime)} · ${group.items.length} 笔'
        : _formatTransDate(item.transTime);

    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      minimumSize: Size.zero,
      onPressed: () => _openTransaction(group.items),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: CupertinoColors.activeBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              item.isRecharge
                  ? Icons.account_balance_wallet_rounded
                  : Icons.credit_card_rounded,
              size: 20,
              color: CupertinoColors.activeBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.subject.isEmpty ? '未知科目' : item.subject,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: primary),
                ),
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, color: secondary)),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // 充值不显示数字，只显示「充值」文字
          Text(
            item.isRecharge ? '充值' : group.totalAmount.toStringAsFixed(2),
            style: TextStyle(fontSize: 17, color: primary),
          ),
          Icon(Icons.chevron_right_rounded, size: 20, color: secondary),
        ],
      ),
    );
  }

  Widget _buildEmptyCard() {
    return IosCard(
      radius: 22,
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text('暂无交易记录',
            style: TextStyle(fontSize: 15, color: textSecondary(context))),
      ),
    );
  }

  // ── 分页预取 ──

  bool _shouldPrefetch(EcardState s, ScrollMetrics m) {
    if (!s.hasMore || s.loadingMore || _loadMorePending) return false;
    final ahead = math.max(1200.0, m.viewportDimension * 2.5);
    if (m.maxScrollExtent <= m.viewportDimension * 0.8) return true;
    return m.pixels >= m.maxScrollExtent - ahead;
  }

  void _maybeLoadMore(EcardState s, ScrollMetrics m) {
    if (!_shouldPrefetch(s, m)) return;
    _loadMorePending = true;
    _controller.loadMore().whenComplete(() {
      if (!mounted) return;
      _loadMorePending = false;
    });
  }

  // ── 日期格式化 ──

  /// 今天 → `今天 H:mm`；昨天 → `昨天 H:mm`；其余 → `yyyy/MM/dd`
  String _formatTransDate(String iso) {
    if (iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final local = d.toLocal();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final time = '${local.hour}:${local.minute.toString().padLeft(2, '0')}';

    if (day == today) return '今天 $time';
    if (day == today.subtract(const Duration(days: 1))) return '昨天 $time';
    final y = local.year.toString();
    final mo = local.month.toString().padLeft(2, '0');
    final da = local.day.toString().padLeft(2, '0');
    return '$y/$mo/$da';
  }
}