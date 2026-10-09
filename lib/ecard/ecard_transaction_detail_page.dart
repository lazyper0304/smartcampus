import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/ios_kit.dart';
import '../core/simple_page.dart';
import '../core/theme_utils.dart';
import 'ecard_model.dart';

/// 交易详情页（单条 / 多笔合并双模态）。
///
/// 参考实现：`E:/project/YibinApp/Flutter/.../ecard_transaction_detail_page.dart`
class EcardTransactionDetailPage extends StatelessWidget {
  EcardTransactionDetailPage({
    super.key,
    required List<EcardTransaction> items,
  })  : items = List<EcardTransaction>.unmodifiable(items),
        assert(items.isNotEmpty);

  EcardTransactionDetailPage.single(EcardTransaction item, {super.key})
      : items = List<EcardTransaction>.unmodifiable([item]);

  final List<EcardTransaction> items;

  bool get _isMerged => items.length > 1;

  @override
  Widget build(BuildContext context) {
    final sorted = [...items]
      ..sort((a, b) => a.transTime.compareTo(b.transTime));
    final total = sorted.fold<double>(0, (acc, e) => acc + e.amount);

    return SimplePage(
      // ⚠️ 文字装饰兜底：无 Material 祖先时可能继承带下划线的DefaultTextStyle
      // （详见 ecard_page.dart 同处注释）
      child: DefaultTextStyle(
        style: TextStyle(
          decoration: TextDecoration.none,
          color: textPrimary(context),
        ),
        child: SafeArea(
        top: false,
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _section(context, '交易信息', [
              _row(context, '科目', items.first.subject.isEmpty ? '未知科目' : items.first.subject),
              _row(context, '交易类型', _transTypeLabel(items.first)),
              _row(
                context,
                _isMerged ? '合计金额' : '金额',
                // 合并组强制按消费展示（累加后可能正负混合）
                _formatAmount(total, isRecharge: _isMerged ? false : items.first.isRecharge),
              ),
              if (_isMerged)
                _row(context, '合并笔数', '${items.length} 笔'),
              if (_isMerged)
                _row(context, '时间区间', _formatRange(sorted)),
              _row(context, '余额', sorted.last.balance.toStringAsFixed(2)),
              _row(context, '交易时间', _formatDateTime(items.first.transTime)),
              _row(context, '钱包类型', _walletLabel(items.first.walletType)),
            ]),
            const SizedBox(height: 20),
            _section(context, '终端信息', [
              _row(context, '终端', items.first.terminal.isEmpty ? '-' : items.first.terminal),
              _row(context, '工作站', items.first.workstation.isEmpty ? '-' : items.first.workstation),
              _row(context, '操作员', items.first.operator.isEmpty ? '-' : items.first.operator),
            ]),
            if (_isMerged) ...[
              const SizedBox(height: 20),
              _buildMergeItems(context, sorted),
            ],
            const SizedBox(height: 20),
            _section(context, '记录信息', [
              _row(context, '记录 ID', items.first.id.toString()),
              _row(context, '用户 ID', items.first.userId.toString()),
              _row(context, '入库时间', _formatDateTime(items.first.createdAt)),
            ]),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildMergeItems(BuildContext context, List<EcardTransaction> sorted) {
    return _section(context, '合并明细', [
      for (var i = 0; i < sorted.length; i++)
        _row(
          context,
          _formatDateTime(sorted[i].transTime),
          _formatAmount(sorted[i].amount, isRecharge: sorted[i].isRecharge),
          onTap: () => Navigator.of(context).push<void>(
            CupertinoPageRoute(
              builder: (_) => EcardTransactionDetailPage.single(sorted[i]),
            ),
          ),
        ),
    ]);
  }

  Widget _section(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title,
              style: TextStyle(fontSize: 13, color: textSecondary(context))),
        ),
        IosCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    VoidCallback? onTap,
  }) {
    final primary = textPrimary(context);
    final secondary = textSecondary(context);
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: TextStyle(fontSize: 15, color: secondary)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(fontSize: 15, color: primary)),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right_rounded, size: 18, color: secondary),
        ],
      ),
    );
    if (onTap == null) return content;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: content,
    );
  }

  static String _formatAmount(double v, {required bool isRecharge}) =>
      isRecharge ? '+${v.toStringAsFixed(2)}' : '-${v.toStringAsFixed(2)}';

  static String _transTypeLabel(EcardTransaction t) => switch (t.transType) {
        0 => '消费',
        1 => '充值',
        _ => '其他',
      };

  static String _walletLabel(int type) => switch (type) {
        0 => '主钱包',
        1 => '补助钱包',
        _ => type.toString(),
      };

  /// `yyyy/MM/dd HH:mm:ss`（补零，带秒）
  static String _formatDateTime(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso.isEmpty ? '-' : iso;
    final l = d.toLocal();
    String p(int v) => v.toString().padLeft(2, '0');
    return '${l.year}/${p(l.month)}/${p(l.day)} '
        '${p(l.hour)}:${p(l.minute)}:${p(l.second)}';
  }

  static String _formatRange(List<EcardTransaction> sorted) {
    if (sorted.isEmpty) return '-';
    if (sorted.length == 1) return _formatDateTime(sorted.first.transTime);
    return '${_formatDateTime(sorted.first.transTime)} — '
        '${_formatDateTime(sorted.last.transTime)}';
  }
}