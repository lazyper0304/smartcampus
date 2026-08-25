/// 首页「电费」卡片：展示剩余电量 / 状态 / 本月用电，整卡可点击进入电费页。
///
/// 数据策略：
///  1. 先读最近一次成功查询的本地缓存（`DianfeiService.loadCachedStatus`）秒显；
///  2. 已绑定时后台实时查询一次刷新（接口无需 cookie）；
///  3. `DianfeiService.query` 失败时静默返回空状态（余额=0、状态为空），
///     以「合闸状态为空」判定失败，保留缓存值不显示误导性的 0。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../core/ios_kit.dart';
import '../core/local_storage.dart';
import '../core/navigation.dart';
import '../core/theme_utils.dart';
import '../main.dart' show accentColorNotifier;
import 'dianfei_models.dart';
import 'dianfei_page.dart';
import 'dianfei_service.dart';

class DianfeiCard extends StatefulWidget {
  const DianfeiCard({super.key});

  @override
  State<DianfeiCard> createState() => _DianfeiCardState();
}

class _DianfeiCardState extends State<DianfeiCard> {
  bool _loading = false;
  bool _bound = false;
  String? _meterId;
  String? _openId;

  DianfeiStatus? _status; // null = 无任何数据（未绑定/从未查到）
  String _updatedAt = '';

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  Future<void> _initLoad() async {
    final meterId = await LocalStorage.getString('dianfei_meterId');
    final openId =
        await LocalStorage.getString('dianfei_wechatUserOpenid');
    if (!mounted) return;
    if (meterId == null ||
        meterId.isEmpty ||
        openId == null ||
        openId.isEmpty) {
      setState(() => _bound = false);
      return;
    }
    _meterId = meterId;
    _openId = openId;

    // 缓存秒显
    final cached = await DianfeiService.loadCachedStatus();
    final cachedAt = await DianfeiService.loadCachedUpdatedAt();
    if (!mounted) return;
    setState(() {
      _bound = true;
      if (cached != null) _status = cached;
      _updatedAt = cachedAt ?? '';
    });

    // 后台实时刷新
    unawaited(_query());
  }

  Future<void> _query() async {
    if (_meterId == null || _openId == null) return;
    setState(() => _loading = true);
    try {
      final result = await DianfeiService.query(
        meterId: _meterId!,
        wechatUserOpenid: _openId!,
      );
      final s = result.status;
      // 服务层失败路径静默返回空状态；以「状态为空」判定本次查询无效
      final valid = s.zhuangtai.isNotEmpty;
      if (valid) {
        unawaited(DianfeiService.cacheStatus(s));
        if (!mounted) return;
        setState(() {
          _status = s;
          _updatedAt = _formatNow();
          _loading = false;
        });
      } else {
        // 查询失败：保留已有缓存值展示
        if (!mounted) return;
        setState(() => _loading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _formatNow() {
    final n = DateTime.now();
    return '${n.month}月${n.day}日 '
        '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return IosCard(
      onTap: () => pushPage(context, const DianfeiPage()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _headerIcon(context),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('电费',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
              Icon(Icons.chevron_right, size: 18, color: textHint(context)),
            ],
          ),
          const SizedBox(height: 14),
          if (!_bound)
            _hintRow(Icons.link_rounded, '点击绑定宿舍电表，查看剩余电量')
          else if (_status == null)
            _loading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(minHeight: 2),
                  )
                : _hintRow(Icons.error_outline_rounded, '暂无数据，点击进入电费页查询')
          else ...[
            _statusRow(context),
            const SizedBox(height: 6),
            Text(
              '本月 ${_status!.monthKwh.toStringAsFixed(1)} 度 · '
              '${_status!.monthMoney.toStringAsFixed(2)} 元'
              '${_updatedAt.isEmpty ? '' : ' · $_updatedAt'}',
              style: TextStyle(fontSize: 12, color: textHint(context)),
            ),
          ],
        ],
      ),
    );
  }

  /// 剩余电量 + 状态徽章行。
  /// 与电费页一致：剩余 <20 度或「分闸」时标深橙（0xFFC2410C）提示电量偏低。
  Widget _statusRow(BuildContext context) {
    final low = _status!.shengyu < 20;
    final off = _status!.zhuangtai.isNotEmpty && _status!.zhuangtai != '合闸';
    final warn = low || off;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          _status!.shengyu.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color:
                warn ? const Color(0xFFC2410C) : accentColorNotifier.value,
            height: 1.0,
          ),
        ),
        const SizedBox(width: 4),
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child:
              Text('度', style: TextStyle(fontSize: 13, color: textSecondary(context))),
        ),
        const Spacer(),
        if (_loading)
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (_status!.zhuangtai.isNotEmpty)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (off ? const Color(0xFFC2410C) : accentColorNotifier.value)
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _status!.zhuangtai,
              style: TextStyle(
                fontSize: 11,
                color: off
                    ? const Color(0xFFC2410C)
                    : accentColorNotifier.value,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _headerIcon(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: accentColorNotifier.value.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(Icons.bolt_rounded,
          color: accentColorNotifier.value, size: 21),
    );
  }

  Widget _hintRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: textHint(context)),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(fontSize: 13, color: textHint(context))),
      ],
    );
  }
}
