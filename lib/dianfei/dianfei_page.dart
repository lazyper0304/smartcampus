import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/local_storage.dart' as store;
import '../core/ios_kit.dart';
import '../core/theme_utils.dart';
import '../core/simple_page.dart';
import '../core/glass_category_bar.dart';
import '../core/glass_action_button.dart';
import '../main.dart';
import 'dianfei_models.dart';
import 'dianfei_service.dart';
import '../widget/widget_service.dart';

class DianfeiPage extends StatefulWidget {
  const DianfeiPage({super.key});
  @override
  State<DianfeiPage> createState() => _DianfeiPageState();
}

class _DianfeiPageState extends State<DianfeiPage> {
  final _meterCtrl = TextEditingController();
  bool _loading = false;
  bool _firstTime = true;
  String _error = '';
  List<DayData> _allDays = [];
  int _viewMode = 1;
  String _meterId = '';
  double _monthKwh = 0;
  double _monthMoney = 0;
  String _monthStr = '';
  double _shengyu = 0;        // 剩余电量
  double _leiji = 0;          // 累计用电
  String _zhuangtai = '';     // 当前状态（合闸/分闸）
  double _price = 0.55;       // 电价
  String _wechatUserOpenid = ''; // 微信 OpenID（从 URL 提取）
  String _wechatUserId = '';  // 微信用户ID（充值用）
  bool _recharging = false;

  /// 最后获取时间（页面显示"数据获取于"）
  String _updatedAt = '';

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  List<DayData> get _displayDays =>
      _viewMode == 0 && _allDays.length > 7
          ? _allDays.sublist(_allDays.length - 7)
          : _allDays;

  Future<void> _initLoad() async {
    final savedUrl = await store.LocalStorage.getString('dianfei_url');
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _meterCtrl.text = savedUrl;
      _firstTime = false;
      _meterId = await store.LocalStorage.getString('dianfei_meterId') ?? '';
      _wechatUserOpenid =
          await store.LocalStorage.getString('dianfei_wechatUserOpenid') ?? '';
      // 实时查询模式：进入页面始终重新获取最新数据（不再读缓存）
      WidgetsBinding.instance.addPostFrameCallback((_) => _query());
    } else {
      setState(() => _firstTime = true);
    }
  }

  Future<void> _query() async {
    final raw = _meterCtrl.text.trim();
    if (raw.isEmpty) { _showSnack('请输入查询链接'); return; }

    // 从 URL 中提取 wechatUserOpenid 和 meterId（DianfeiService.parseLink）
    final parsed = DianfeiService.parseLink(raw);
    if (parsed == null) {
      _showSnack('链接格式错误，请检查是否包含 wechatUserOpenid 和 meterId');
      return;
    }
    final meterId = parsed.meterId;
    final wechatUserOpenid = parsed.openId;

    setState(() {
      _loading = true; _error = ''; _allDays = [];
      _monthKwh = 0; _monthMoney = 0; _monthStr = '';
      _shengyu = 0; _leiji = 0; _zhuangtai = '';
      _wechatUserId = '';
      _meterId = meterId;
      _wechatUserOpenid = wechatUserOpenid;
    });

    await store.LocalStorage.setString('dianfei_url', raw);
    await store.LocalStorage.setString('dianfei_meterId', meterId);
    await store.LocalStorage.setString('dianfei_wechatUserOpenid', wechatUserOpenid);

    // 桌面组件：保存查询参数（原生端直接实时查询，无需 cookie）+ 最新快照（非阻塞）
    WidgetService.saveDianfeiParams(
      meterId,
      wechatUserOpenid,
      isAfter: DianfeiService.isAfterMoney(raw),
    );

    try {
      final result = await DianfeiService.query(
        meterId: meterId,
        wechatUserOpenid: wechatUserOpenid,
      );
      final s = result.status;
      _wechatUserId = s.wechatUserId;
      final updatedAt = _formatNow();

      // 桌面组件：查询成功后同步最新快照（非阻塞）
      WidgetService.saveDianfeiData(
        WidgetService.buildDianfeiData(
          status: s,
          days: result.days,
        ),
      );

      if (!mounted) return;
      setState(() {
        _allDays = result.days;
        _shengyu = s.shengyu;
        _leiji = s.leiji;
        _zhuangtai = s.zhuangtai;
        _price = s.price;
        _monthKwh = s.monthKwh;
        _monthMoney = s.monthMoney;
        _monthStr = s.monthStr;
        _firstTime = false;
        _loading = false;
        _updatedAt = updatedAt;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _formatNow() {
    final n = DateTime.now();
    final hh = n.hour.toString().padLeft(2, '0');
    final mm = n.minute.toString().padLeft(2, '0');
    return '${n.month}月${n.day}日 $hh:$mm';
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  Future<void> _unbind() async {
    final confirm = await showDialog<bool>(
      context: context,
      // 淡遮罩：玻璃 Dialog 透出页面背景
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        // 磨砂玻璃弹窗（同其他页面弹窗：模糊 + 半透明渐变）
        child: glassDialog(
          context: ctx,
          radius: 20,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('解绑电表',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Text('确定解绑电表 #$_meterId 吗？解绑后可绑定新电表。',
                    style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('取消')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text('解绑',
                            style: TextStyle(color: Color(0xFFC2410C)))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirm != true) return;

    await store.LocalStorage.remove('dianfei_meterId');
    await store.LocalStorage.remove('dianfei_url');
    await store.LocalStorage.remove('dianfei_wechatUserOpenid');
    // 清理电费本地存储（绑定参数 / 旧缓存键，幂等）
    await store.LocalStorage.remove('dianfei_shengyu');
    await store.LocalStorage.remove('dianfei_leiji');
    await store.LocalStorage.remove('dianfei_zhuangtai');
    await store.LocalStorage.remove('dianfei_price');
    await store.LocalStorage.remove('dianfei_monthKwh');
    await store.LocalStorage.remove('dianfei_monthMoney');
    await store.LocalStorage.remove('dianfei_monthStr');
    await store.LocalStorage.remove('dianfei_days');
    await store.LocalStorage.remove('dianfei_updatedAt');
    await store.LocalStorage.remove('dianfei_cached');
    // 桌面组件：清空原生端查询参数，组件刷新将提示先绑定电表
    WidgetService.saveDianfeiParams('', '');
    if (!mounted) return;
    setState(() {
      _firstTime = true;
      _allDays = [];
      _monthKwh = 0;
      _monthMoney = 0;
      _monthStr = '';
      _shengyu = 0;
      _leiji = 0;
      _zhuangtai = '';
      _wechatUserId = '';
      _wechatUserOpenid = '';
      _meterId = '';
      _meterCtrl.clear();
    });
    _showSnack('已解绑电表');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // ⚠️ 必须包 SimplePage（自带 LiquidBackground 背景层，随路由一起滑入）：
    // 裸 Scaffold（透明背景）转场时"透明页面滑入、透出底层"，
    // 表现为只有临港电费进入时有透明阶段（其它二级页均有 SimplePage）。
    return SimplePage(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('临港电费'),
          centerTitle: true,
          actions: [
            if (!_firstTime) ...[
              IconButton(
                icon: const Icon(Icons.link_off_rounded, size: 20),
                tooltip: '解绑电表',
                onPressed: _unbind,
              ),
              IconButton(icon: const Icon(Icons.refresh_rounded, size: 20),
                  tooltip: '重新获取电费数据',
                  onPressed: _loading ? null : _query),
              IconButton(
                icon: _recharging
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.payments_rounded, size: 20),
                tooltip: '电费充值',
                onPressed: _recharging ? null : _showRechargeSheet,
              ),
            ],
          ],
        ),
        body: _firstTime ? _buildSetup() : _buildResult(isDark),
      ),
    );
  }

  Widget _buildSetup() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        Center(child: Icon(Icons.electrical_services_rounded, size: 64, color: accentColorNotifier.value.withValues(alpha: 0.3))),
        const SizedBox(height: 16),
        const Center(child: Text('绑定电表', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '首次使用请在小程序中打开电费查询页面，\n复制链接粘贴到下方输入框中',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, color: textSecondary(context), height: 1.5),
          ),
        ),
        const SizedBox(height: 24),
        // 链接输入框：直接用全局输入框主题（玻璃填充 + 圆角 12 描边 +
        // 中性白聚焦边框），与登录页 / 课程查询搜索框风格统一；
        // 去掉手写实色 Card 包装（会盖住玻璃背景）。
        // 单行输入：链接粘贴场景文字垂直居中（多行框内容不满时文字
        // 贴顶、看起来没居中）；长链接自动横向滚动。
        TextField(
          controller: _meterCtrl,
          maxLines: 1,
          style: const TextStyle(fontSize: 14),
          decoration: const InputDecoration(
            labelText: '查询链接',
            hintText: '粘贴完整的电费查询链接…',
            prefixIcon: Icon(Icons.link_rounded, size: 20),
          ),
        ),
        const SizedBox(height: 20),
        // 绑定并查询：玻璃操作按钮（GlassActionButton）
        GlassActionButton(
          label: _loading ? '查询中…' : '绑定并查询',
          icon: Icons.link_rounded,
          loading: _loading,
          onPressed: _loading
              ? null
              : () {
                  _query();
                },
        ),
      ],
    );
  }

  Widget _buildResult(bool isDark) {
    if (_loading) {
      // 玻璃卡加载态：转场滑入时页面有内容，避免"全透明页面 + 转圈"的空感
      return Center(
        child: contentCardGlass(
          context: context,
          borderRadius: BorderRadius.circular(16),
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 14),
              Text('正在查询电费…',
                  style:
                      TextStyle(fontSize: 13, color: textSecondary(context))),
            ],
          ),
        ),
      );
    }
    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 12),
            // 应用界面错误文字统一深橙（不用红色）
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(_error, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFC2410C), fontSize: 13)),
            ),
            const SizedBox(height: 20),
            TextButton.icon(icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('重试'), onPressed: _query),
          ],
        ),
      );
    }
    if (_allDays.isEmpty) return const Center(child: Text('暂无数据\n请确认电表号是否正确'));

    final days = _displayDays;
    double total = 0, maxKwh = 0;
    for (final d in days) { total += d.kwh; if (d.kwh > maxKwh) maxKwh = d.kwh; }
    final avg = total / days.length;
    final monthLabel = days.isNotEmpty && days.first.date.length >= 5 ? days.first.date.substring(0, 2) : '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        // 数据获取日期提示（实时查询模式：每次进入页面都会重新获取）
        if (_updatedAt.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.schedule, size: 11, color: textHint(context)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '数据获取于 $_updatedAt · 点右上角刷新可重新获取',
                    style: TextStyle(fontSize: 10.5, color: textHint(context)),
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: accentColorNotifier.value.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.electrical_services_rounded, size: 20, color: accentColorNotifier.value),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('电表 #$_meterId', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                  Text('${days.length} 天记录', style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey[600])),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 剩余电量卡片（静态玻璃，同其他页面卡片）
        contentCardGlass(
          context: context,
          borderRadius: BorderRadius.circular(16),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('剩余电量',
                      style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : Colors.grey[600])),
                  if (_zhuangtai.isNotEmpty)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: (_zhuangtai == '合闸'
                                ? accentColorNotifier.value
                                : const Color(0xFFC2410C))
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(_zhuangtai,
                          style: TextStyle(
                              fontSize: 11,
                              color: _zhuangtai == '合闸'
                                  ? accentColorNotifier.value
                                  : const Color(0xFFC2410C))),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_shengyu.toStringAsFixed(1)}',
                    style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: _shengyu < 20
                            ? const Color(0xFFC2410C)
                            : (isDark ? Colors.white : Colors.black87)),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 4),
                    child: Text('kWh',
                        style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white60 : Colors.grey[600])),
                  ),
                  const Spacer(),
                  if (_shengyu > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('≈ ¥${(_shengyu * _price).toStringAsFixed(1)}',
                          style: TextStyle(
                              fontSize: 15,
                              color: isDark ? Colors.white70 : Colors.grey[700])),
                    ),
                ],
              ),
              if (_leiji > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Text('累计用电 ${_leiji.toStringAsFixed(1)} kWh',
                          style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white60 : Colors.grey[600])),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // 本月汇总卡片（静态玻璃）
        if (_monthKwh > 0)
          contentCardGlass(
            context: context,
            borderRadius: BorderRadius.circular(16),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              children: [
                Text(_monthStr.isNotEmpty ? '$_monthStr 用电' : '本月用电',
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.grey[600])),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _summaryItem('用电量', '${_monthKwh.toStringAsFixed(1)} kWh'),
                    Container(
                        width: 1,
                        height: 30,
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.1)),
                    _summaryItem('电费', '¥${_monthMoney.toStringAsFixed(2)}'),
                  ],
                ),
              ],
            ),
          ),
        if (_monthKwh > 0) const SizedBox(height: 12),
        // 近7天/近30天切换：统一玻璃分类栏（GlassCategoryBar 公共组件，
        // 与应用页分类栏同款：玻璃卡 + 竖分割线 + 选中项 accent 背景）
        GlassCategoryBar(
          items: const [
            GlassCategoryItem(label: '近7天', icon: Icons.today),
            GlassCategoryItem(label: '近30天', icon: Icons.date_range),
          ],
          selectedIndex: _viewMode,
          onSelected: (i) => setState(() => _viewMode = i),
        ),
        const SizedBox(height: 12),
        // 可切换内容（带动画）
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
          child: Column(
            key: ValueKey('view_$_viewMode'),
            children: [
              // 时段汇总卡片（静态玻璃）
              contentCardGlass(
                context: context,
                borderRadius: BorderRadius.circular(16),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text('近${days.length}天用电',
                        style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : Colors.grey[600])),
                    const SizedBox(height: 8),
                    Text('${total.toStringAsFixed(1)} kWh',
                        style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 4),
                    Text('日均 ${avg.toStringAsFixed(1)} kWh · 预估 ¥${(total * _price).toStringAsFixed(2)}',
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.grey[600])),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 折线图（静态玻璃卡片）
              contentCardGlass(
                context: context,
                borderRadius: BorderRadius.circular(16),
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('每日用电量',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87)),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 180,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            SizedBox(
                              width: 32,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${maxKwh.toStringAsFixed(0)}', style: TextStyle(fontSize: 9, color: isDark ? Colors.white38 : Colors.grey[500])),
                                  Text('${(maxKwh/2).toStringAsFixed(0)}', style: TextStyle(fontSize: 9, color: isDark ? Colors.white38 : Colors.grey[500])),
                                  Text('0', style: TextStyle(fontSize: 9, color: isDark ? Colors.white38 : Colors.grey[500])),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: CustomPaint(
                                size: const Size(double.infinity, 180),
                                painter: _LineChartPainter(
                                  data: days.map((d) => d.kwh).toList(),
                                  maxValue: maxKwh,
                                  lineColor: accentColorNotifier.value,
                                  fillColor: accentColorNotifier.value.withValues(alpha: 0.12),
                                  gridColor: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                                  dotColor: accentColorNotifier.value,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 36),
                        child: Row(
                          children: days.asMap().entries.map((e) {
                            final i = e.key;
                            final d = e.value;
                            final showLabel = i % 5 == 0 || i == days.length - 1;
                            final label = d.date.length > 5 ? d.date.substring(d.date.length - 5) : d.date;
                            return Expanded(
                              child: showLabel
                                  ? Text(label,
                                      style: const TextStyle(fontSize: 8, color: Colors.grey),
                                      textAlign: TextAlign.center)
                                  : const SizedBox.shrink(),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
              ),
              const SizedBox(height: 16),
              Text('逐日明细', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 8),
              ...days.reversed.map((d) {
          final ratio = maxKwh > 0 ? d.kwh / maxKwh : 0.0;
          // 逐日明细行玻璃化：与页面其它卡片（contentCardGlass）一致，
          // 去掉手写 Card 实色覆盖（深色模式 grey[850] 会盖住玻璃背景）
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: contentCardGlass(
              context: context,
              borderRadius: BorderRadius.circular(12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  SizedBox(width: 36, child: Text(d.date, style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.grey[700]))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: ratio, minHeight: 6,
                        backgroundColor: accentColorNotifier.value.withValues(alpha: 0.06),
                        valueColor: AlwaysStoppedAnimation<Color>(d.kwh > 15 ? Colors.orange : accentColorNotifier.value.withValues(alpha: 0.7)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(width: 52, child: Text('${d.kwh.toStringAsFixed(1)}', textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87))),
                ],
              ),
            ),
          );
        }),
      ],   // Column children
    ),     // Column
  ),       // AnimatedSwitcher
],
    );
  }

  void _showRechargeSheet() {
    double? selectedAmount;
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final amounts = [10, 20, 30, 50, 100, 200];
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(
                    color: Colors.grey[300], borderRadius: BorderRadius.circular(2),
                  )),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: accentColorNotifier.value.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.electrical_services_rounded, size: 20, color: accentColorNotifier.value),
                      ),
                      const SizedBox(width: 12),
                      const Text('电费充值', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('电表 #$_meterId', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  const SizedBox(height: 20),
                  Text('选择充值金额', style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.grey[700])),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12, runSpacing: 12,
                    children: amounts.map((amt) {
                      final isSelected = selectedAmount == amt;
                      return GestureDetector(
                        onTap: () => setSheetState(() => selectedAmount = amt.toDouble()),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          width: (MediaQuery.of(ctx).size.width - 72) / 3,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? accentColorNotifier.value.withValues(alpha: 0.15)
                                : accentColorNotifier.value.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? accentColorNotifier.value : accentColorNotifier.value.withValues(alpha: 0.2),
                              width: isSelected ? 2.0 : 1.0,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text('¥$amt', style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w700,
                                color: isSelected ? accentColorNotifier.value : accentColorNotifier.value.withValues(alpha: 0.7),
                              )),
                              if (isSelected)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Icon(Icons.check_circle, size: 16, color: accentColorNotifier.value),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  // 生成订单：玻璃操作按钮（未选金额时自动禁用弱化）
                  GlassActionButton(
                    label: '生成订单',
                    icon: Icons.receipt_long_rounded,
                    fontSize: 16,
                    onPressed: selectedAmount == null
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            _doRecharge(selectedAmount!);
                          },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _doRecharge(double amount) async {
    if (_wechatUserId.isEmpty) {
      _showSnack('无法获取用户信息，请先刷新查询');
      return;
    }

    setState(() => _recharging = true);

    try {
      final paymentId = await DianfeiService.createRechargeOrder(
        meterId: _meterId,
        wechatUserOpenid: _wechatUserOpenid,
        amount: amount,
      );
      if (paymentId == null || !mounted) return;

      final payUrl = 'http://dfcz.yibinu.edu.cn/electricmeter/index.html'
          '#/pages/meterlist/meterpayconfirm'
          '?paymentId=$paymentId&wechatUserOpenid=$_wechatUserOpenid&meterId=$_meterId';

      if (!mounted) return;
      _showRechargeResult(payUrl, amount);
    } catch (e) {
      if (mounted) _showSnack('充值失败: $e');
    } finally {
      if (mounted) setState(() => _recharging = false);
    }
  }

  void _showRechargeResult(String payUrl, double amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      // 淡遮罩：玻璃 Dialog 透出页面背景
      barrierColor: Colors.black.withValues(alpha: 0.25),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        // 磨砂玻璃弹窗（同其他页面弹窗：模糊 + 半透明渐变）
        child: glassDialog(
          context: ctx,
          radius: 20,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[600], size: 24),
                    const SizedBox(width: 10),
                    const Text('订单已创建',
                        style:
                            TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: accentColorNotifier.value.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('充值金额',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey[600])),
                          Text('¥${amount.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: accentColorNotifier.value,
                              )),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('电表 #$_meterId',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[500])),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('支付链接',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700])),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).brightness == Brightness.dark
                        ? Colors.grey[850]
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    payUrl,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.wechat_rounded, size: 20),
                    label: const Text('复制并打开微信',
                        style: TextStyle(fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF07C160),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: payUrl));
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('链接已复制，请在微信中粘贴打开完成支付'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 3),
                        ),
                      );
                      launchUrl(Uri.parse('weixin://'),
                          mode: LaunchMode.externalApplication);
                      Navigator.pop(ctx);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child:
                        Text('关闭', style: TextStyle(color: Colors.grey[600])),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _meterCtrl.dispose();
    super.dispose();
  }

  Widget _summaryItem(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white60 : Colors.grey[600])),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87)),
      ],
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> data;
  final double maxValue;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;
  final Color dotColor;

  _LineChartPainter({
    required this.data, required this.maxValue,
    required this.lineColor, required this.fillColor,
    required this.gridColor, required this.dotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || maxValue <= 0) return;
    final h = size.height;
    final w = size.width;
    final stepX = data.length > 1 ? w / (data.length - 1) : w;

    // 网格线
    final gridPaint = Paint()..color = gridColor..strokeWidth = 0.5;
    for (int i = 0; i <= 2; i++) {
      final y = h * (1 - i / 2.0);
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // 计算数据点
    final pts = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = h - (data[i] / maxValue) * h * 0.92;
      pts.add(Offset(x, y));
    }

    // 填充区域（从底部到曲线再到底部）
    if (pts.length >= 2) {
      final fillPath = Path()..moveTo(pts.first.dx, h);
      fillPath.lineTo(pts.first.dx, pts.first.dy);
      _addSmoothPath(fillPath, pts, startNew: false);
      fillPath.lineTo(pts.last.dx, h);
      fillPath.close();
      canvas.drawPath(fillPath, Paint()..color = fillColor);
    }

    // 折线
    final linePath = Path();
    _addSmoothPath(linePath, pts, startNew: true);
    canvas.drawPath(linePath, Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round);

    // 数据点
    for (final p in pts) {
      canvas.drawCircle(p, 3.5, Paint()..color = Colors.white);
      canvas.drawCircle(p, 3, Paint()..color = dotColor);
    }
  }

  /// Catmull-Rom → 三次贝塞尔平滑曲线
  void _addSmoothPath(Path path, List<Offset> pts, {bool startNew = true}) {
    if (pts.isEmpty) return;
    if (startNew) path.moveTo(pts[0].dx, pts[0].dy);
    if (pts.length < 3) {
      for (int i = 1; i < pts.length; i++) path.lineTo(pts[i].dx, pts[i].dy);
      return;
    }
    for (int i = 0; i < pts.length - 1; i++) {
      final p0 = i > 0 ? pts[i - 1] : pts[i];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = i < pts.length - 2 ? pts[i + 2] : pts[i + 1];
      path.cubicTo(
        p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6,
        p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6,
        p2.dx, p2.dy,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
