import 'package:flutter/cupertino.dart';

import '../core/responsive.dart';
import '../core/simple_page.dart';
import '../core/theme_utils.dart';
import 'order_qrcode_detail_page.dart';
import 'order_qrcode_model.dart';
import 'order_qrcode_service.dart';
import 'order_qrcode_submit_page.dart';
import 'widgets/order_qrcode_widgets.dart';

/// 我的上传（含「上传点餐码」入口 + 我提交过的记录）。
///
/// 参考实现 `order_qrcode_my_page.dart`（BingoApp）。
class OrderQrcodeMyPage extends StatefulWidget {
  const OrderQrcodeMyPage({super.key});

  @override
  State<OrderQrcodeMyPage> createState() => _OrderQrcodeMyPageState();
}

class _OrderQrcodeMyPageState extends State<OrderQrcodeMyPage> {
  final OrderQrcodeService _service = OrderQrcodeService.instance;

  List<OrderQRCode> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _service.myUploads();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '数据获取失败，请稍后重试';
      });
    }
  }

  Future<void> _openSubmit() async {
    final ok = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(builder: (_) => const OrderQrcodeSubmitPage()),
    );
    if (ok == true && mounted) await _load();
  }

  void _openItem(OrderQRCode item) {
    final page = item.status == 'approved'
        ? OrderQrcodeDetailPage(item: item)
        : OrderQrcodeMyUploadDetailPage(item: item);
    Navigator.of(context).push<void>(
      CupertinoPageRoute(builder: (_) => page),
    );
  }

  static Color _statusColor(String status) => switch (status) {
        'approved' => const Color(0xFF34C759),
        'pending' => kOrderRatingColor,
        'rejected' => const Color(0xFFFF3B30),
        _ => kOrderRatingColor,
      };

  @override
  Widget build(BuildContext context) {
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
                      '我的上传',
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
            const SizedBox(height: 16),
            OrderSettingsGroup(
              children: [
                OrderActionRow(label: '上传点餐码', onTap: _openSubmit),
              ],
            ),
            const SizedBox(height: 24),
            const OrderSectionHeader('我提交的'),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CupertinoActivityIndicator()),
              )
            else if (_error != null)
              OrderSettingsGroup(
                children: [
                  OrderActionRow(label: '重新加载', onTap: _load),
                ],
              )
            else if (_items.isEmpty)
              OrderSettingsGroup(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 28),
                    child: Text(
                      '还没有上传过点餐码',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: textSecondary(context),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              )
            else
              OrderSettingsGroup(
                children: [
                  for (final it in _items)
                    _MyUploadRow(
                      title: it.shopName,
                      statusLabel: OrderQrcodeUtils.statusLabel(it.status),
                      statusColor: _statusColor(it.status),
                      onTap: () => _openItem(it),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// 我的上传行（店名 + 状态 + 箭头）
class _MyUploadRow extends StatelessWidget {
  const _MyUploadRow({
    required this.title,
    required this.statusLabel,
    required this.statusColor,
    required this.onTap,
  });

  final String title;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: textPrimary(context),
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              statusLabel,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: statusColor,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(width: 4),
            Icon(CupertinoIcons.chevron_right,
                size: 15, color: textSecondary(context)),
          ],
        ),
      ),
    );
  }
}

/// 未通过 / 审核中记录的详情（不展示二维码，只展示审核信息）
class OrderQrcodeMyUploadDetailPage extends StatelessWidget {
  const OrderQrcodeMyUploadDetailPage({super.key, required this.item});

  final OrderQRCode item;

  static String _dash(String v) => v.isEmpty ? '-' : v;

  static String _formatDateTime(String iso) {
    if (iso.isEmpty) return '-';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final local = d.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}/${two(local.month)}/${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
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
                      '上传详情',
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
            const SizedBox(height: 16),
            const OrderSectionHeader('商家信息'),
            OrderSettingsGroup(
              children: [
                OrderInfoRow(label: '商家名称', value: _dash(item.shopName)),
                OrderInfoRow(label: '校区', value: _dash(item.campus)),
                OrderInfoRow(label: '位置', value: _dash(item.location)),
                OrderInfoRow(label: '分类', value: _dash(item.shopCategory)),
                if (item.description.isNotEmpty)
                  OrderInfoRow(label: '说明', value: item.description),
              ],
            ),
            const SizedBox(height: 24),
            const OrderSectionHeader('审核状态'),
            OrderSettingsGroup(
              children: [
                OrderInfoRow(
                  label: '状态',
                  value: OrderQrcodeUtils.statusLabel(item.status),
                ),
                OrderInfoRow(label: '提交时间', value: _formatDateTime(item.createdAt)),
                if (item.status == 'rejected' && item.rejectReason.isNotEmpty)
                  OrderInfoRow(label: '未通过原因', value: item.rejectReason),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
