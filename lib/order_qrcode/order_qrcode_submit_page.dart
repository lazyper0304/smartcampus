import 'package:flutter/cupertino.dart';

import '../core/responsive.dart';
import '../core/simple_page.dart';
import '../core/theme_utils.dart';
import 'order_qrcode_model.dart';
import 'order_qrcode_scan_page.dart';
import 'order_qrcode_service.dart';
import 'widgets/order_qrcode_widgets.dart';

/// 上传点餐码（设置页分组列表风格：无 chip、无内联多行输入框）。
///
/// 参考实现 `order_qrcode_submit_page.dart`（BingoApp）。差异：
/// - 文本输入用 Cupertino 弹窗（本项目没有 `TextEditPage` 这一通用页）；
/// - 桌面端无相机实现 → 用「手动输入二维码内容」兜底。
class OrderQrcodeSubmitPage extends StatefulWidget {
  const OrderQrcodeSubmitPage({super.key});

  @override
  State<OrderQrcodeSubmitPage> createState() => _OrderQrcodeSubmitPageState();
}

class _OrderQrcodeSubmitPageState extends State<OrderQrcodeSubmitPage> {
  final OrderQrcodeService _service = OrderQrcodeService.instance;

  String _campus = '';
  String _category = '';
  String _shopName = '';
  String _location = '';
  String _description = '';
  String _qrContent = '';
  String _qrType = '';
  bool _submitting = false;

  Future<void> _scan() async {
    final result = await Navigator.of(context).push<String>(
      CupertinoPageRoute(builder: (_) => const OrderQrcodeScanPage()),
    );
    if (result == null || result.isEmpty || !mounted) return;
    await _applyQrContent(result);
  }

  /// 扫码/手工录入后统一走查重
  Future<void> _applyQrContent(String content) async {
    try {
      final dup = await _service.check(content);
      if (!mounted) return;
      if (dup.duplicate) {
        final msg = dup.status == 'approved'
            ? '该点餐码已被「${dup.shopName ?? ''}」收录'
            : '该点餐码已提交，正在审核中';
        await _alert('重复的点餐码', msg);
        return;
      }
    } catch (_) {
      // 查重失败不阻断提交（提交时服务端还会再查一次）
    }
    if (!mounted) return;
    setState(() {
      _qrContent = content;
      _qrType = OrderQrcodeUtils.detectQrType(content);
    });
  }

  Future<void> _manualInput() async {
    final value = await _openTextEdit(
      title: '二维码内容',
      initial: _qrContent,
      placeholder: '粘贴扫码得到的链接或文本',
      maxLength: 500,
      maxLines: 4,
    );
    if (value == null || value.trim().isEmpty || !mounted) return;
    await _applyQrContent(value.trim());
  }

  Future<void> _pickCampus() async {
    final picked = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('选择校区'),
        actions: [
          for (final c in OrderQrcodeUtils.campusPresets)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx, c),
              child: Text(c),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _campus = picked);
  }

  Future<void> _pickCategory() async {
    final picked = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('选择分类'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('不分类'),
          ),
          for (final c in OrderQrcodeUtils.categoryPresets)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx, c),
              child: Text(c),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _category = picked);
  }

  Future<String?> _openTextEdit({
    required String title,
    required String initial,
    required String placeholder,
    int maxLength = 100,
    int maxLines = 1,
  }) {
    return showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => _OrderTextEditDialog(
        title: title,
        initial: initial,
        placeholder: placeholder,
        maxLength: maxLength,
        maxLines: maxLines,
      ),
    );
  }

  Future<void> _editShop() async {
    final v = await _openTextEdit(
      title: '商家名称',
      initial: _shopName,
      placeholder: '例如：三食堂·张记面馆',
      maxLength: 60,
    );
    if (v != null && mounted) setState(() => _shopName = v.trim());
  }

  Future<void> _editLocation() async {
    final v = await _openTextEdit(
      title: '所在位置',
      initial: _location,
      placeholder: '例如：三食堂一楼东侧',
      maxLength: 80,
    );
    if (v != null && mounted) setState(() => _location = v.trim());
  }

  Future<void> _editDescription() async {
    final v = await _openTextEdit(
      title: '补充说明',
      initial: _description,
      placeholder: '推荐菜品、扫码方式等（选填）',
      maxLength: 200,
      maxLines: 5,
    );
    if (v != null && mounted) setState(() => _description = v.trim());
  }

  String _placeholderOr(String value, String placeholder) =>
      value.trim().isEmpty ? placeholder : value.trim();

  String _ellipsis(String value, [int maxLen = 20]) {
    if (value.length <= maxLen) return value;
    return '${value.substring(0, maxLen)}…';
  }

  Future<void> _submit() async {
    if (_campus.isEmpty || _shopName.trim().isEmpty || _qrContent.isEmpty) {
      await _alert('信息不完整', '请先扫码并填写校区、商家名称');
      return;
    }
    setState(() => _submitting = true);
    try {
      final dup = await _service.check(_qrContent);
      if (dup.duplicate) {
        if (mounted) await _alert('重复的点餐码', '该点餐码已提交，正在审核中');
        return;
      }
      await _service.submit(
        campus: _campus,
        shopName: _shopName.trim(),
        shopCategory: _category,
        location: _location.trim(),
        qrContent: _qrContent,
        qrType: _qrType,
        description: _description.trim(),
      );
      if (!mounted) return;
      await _alert('提交成功', '审核通过后将出现在点餐码列表');
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        await _alert('提交失败', e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _alert(String title, String msg) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(msg),
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
    final topPad = MediaQuery.viewPaddingOf(context).top + 44;
    final bottomInset = systemBottomInset(context);
    final qrStatus = _qrContent.isEmpty
        ? '未扫码'
        : OrderQrcodeUtils.qrTypeLabel(_qrType);

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
                      '上传点餐码',
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
            const OrderSectionHeader('二维码'),
            OrderSettingsGroup(
              children: [
                // ⚠️ 桌面端（Windows/Linux）没有相机实现：只暴露「手动输入」
                if (supportsQrScan)
                  OrderLinkRow(
                    label: '扫码',
                    value: qrStatus,
                    onTap: _scan,
                  ),
                OrderLinkRow(
                  label: supportsQrScan ? '手动输入' : '填写二维码内容',
                  value: _qrContent.isEmpty ? '粘贴链接或文本' : qrStatus,
                  onTap: _manualInput,
                ),
                if (_qrContent.isNotEmpty)
                  OrderLinkRow(
                    label: '清除',
                    value: '',
                    onTap: () => setState(() {
                      _qrContent = '';
                      _qrType = '';
                    }),
                    showChevron: false,
                    valueColor: const Color(0xFFFF3B30),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const OrderSectionHeader('商家信息'),
            OrderSettingsGroup(
              children: [
                OrderLinkRow(
                  label: '校区',
                  value: _placeholderOr(_campus, '必选'),
                  onTap: _pickCampus,
                ),
                OrderLinkRow(
                  label: '商家名称',
                  value: _ellipsis(_placeholderOr(_shopName, '必填')),
                  onTap: _editShop,
                ),
                OrderLinkRow(
                  label: '分类',
                  value: _category.isEmpty ? '不分类' : _category,
                  onTap: _pickCategory,
                ),
                OrderLinkRow(
                  label: '所在位置',
                  value: _ellipsis(_placeholderOr(_location, '选填')),
                  onTap: _editLocation,
                ),
                OrderLinkRow(
                  label: '补充说明',
                  value: _ellipsis(_placeholderOr(_description, '选填')),
                  onTap: _editDescription,
                ),
              ],
            ),
            const SizedBox(height: 24),
            OrderSettingsGroup(
              children: [
                OrderActionRow(
                  label: '提交',
                  loading: _submitting,
                  onTap: _submit,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 简易文本编辑弹窗（对应参考工程的 `TextEditPage`）
class _OrderTextEditDialog extends StatefulWidget {
  const _OrderTextEditDialog({
    required this.title,
    required this.initial,
    required this.placeholder,
    required this.maxLength,
    required this.maxLines,
  });

  final String title;
  final String initial;
  final String placeholder;
  final int maxLength;
  final int maxLines;

  @override
  State<_OrderTextEditDialog> createState() => _OrderTextEditDialogState();
}

class _OrderTextEditDialogState extends State<_OrderTextEditDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: Text(widget.title),
      content: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: CupertinoTextField(
          controller: _ctrl,
          autofocus: true,
          maxLines: widget.maxLines,
          maxLength: widget.maxLength,
          placeholder: widget.placeholder,
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context, _ctrl.text),
          child: const Text('确定'),
        ),
      ],
    );
  }
}
