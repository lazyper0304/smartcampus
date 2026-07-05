import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/local_storage.dart' as store;
import '../core/data_cache.dart';

const Color _yibinBlue = Color.fromRGBO(25, 25, 153, 1);

class _DayData {
  final String date;
  final double kwh;
  _DayData(this.date, this.kwh);
}

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
  List<_DayData> _allDays = [];
  int _viewMode = 1;
  String _meterId = '';
  double _monthKwh = 0;
  double _monthMoney = 0;
  String _monthStr = '';
  double _shengyu = 0;        // 剩余电量
  double _leiji = 0;          // 累计用电
  String _zhuangtai = '';     // 当前状态（合闸/分闸）
  double _price = 0.55;       // 电价
  String _wechatUserId = '';  // 微信用户ID（充值用）
  bool _recharging = false;

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  List<_DayData> get _displayDays =>
      _viewMode == 0 && _allDays.length > 7
          ? _allDays.sublist(_allDays.length - 7)
          : _allDays;

  Future<void> _initLoad() async {
    final saved = await store.LocalStorage.getString('dianfei_meterId');
    if (saved != null && saved.isNotEmpty) {
      _meterCtrl.text = saved;
      _firstTime = false;
      _meterId = saved;
      WidgetsBinding.instance.addPostFrameCallback((_) => _query());
    } else {
      setState(() => _firstTime = true);
    }
  }

  Future<void> _query() async {
    final meterId = _meterCtrl.text.trim();
    if (meterId.isEmpty) { _showSnack('请输入电表号'); return; }

    setState(() { _loading = true; _error = ''; _allDays = []; _monthKwh = 0; _monthMoney = 0; _monthStr = ''; _shengyu = 0; _leiji = 0; _zhuangtai = ''; _wechatUserId = ''; _meterId = meterId; });
    await store.LocalStorage.setString('dianfei_meterId', meterId);

    try {
      final data = await _fetchApi(meterId);
      setState(() {
        _allDays = data;
        _firstTime = false;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<List<_DayData>> _fetchApi(String meterId) async {
    final cacheKey = 'dianfei_$meterId';
    final cached = DataCache().get<List<_DayData>>(cacheKey);
    if (cached != null) return cached;
    final completer = Completer<List<_DayData>>();
    final url = 'http://dfcz.yibinu.edu.cn/electricmeter/index.html'
        '#/pages/meterlist/meterqueryChart'
        '?wechatUserOpenid=oBY1y5qCDUCD1muCFD8lblZIOXr8&meterId=$meterId';

    bool started = false;

    final headless = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true, domStorageEnabled: true,
        userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36',
      ),
      onLoadStop: (ctrl, url) async {
        if (started) return;
        started = true;

        await Future.delayed(const Duration(seconds: 5));
        if (completer.isCompleted) return;

        // 调用三个 API：余量查询 + 月度汇总 + 日度明细
        final js = r'''
(function() {
  try {
    var meterId = (location.href.match(/meterId=(\d+)/) || ['',''])[1];
    var openId = (location.href.match(/wechatUserOpenid=([^&]+)/) || ['',''])[1];
    var remark = (location.href.match(/elemeterTypeRemark=([^&]+)/) || ['',''])[1];
    var isAfter = (remark && decodeURIComponent(remark).indexOf('后付费') >= 0) ? 1 : 0;
    var now = new Date();
    var y = now.getFullYear();
    var m = String(now.getMonth()+1).padStart(2,'0');
    var d = String(now.getDate()).padStart(2,'0');
    var past = new Date(now.getTime() - 30*24*60*60*1000);
    var py = past.getFullYear();
    var pm = String(past.getMonth()+1).padStart(2,'0');
    var pd = String(past.getDate()).padStart(2,'0');

    // 接口0: 获取微信用户信息（得到 wechatId）
    var xhr00 = new XMLHttpRequest();
    xhr00.open('POST', 'http://dfcz.yibinu.edu.cn/kddz/electricmeterpost/index', false);
    xhr00.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
    xhr00.send('openId=' + openId);
    var userResp = JSON.parse(xhr00.responseText);
    var wechatUserId = '';
    if (userResp.code == 200 && userResp.data) {
      wechatUserId = userResp.data.wechatId;
    }

    // 接口1: 余量查询（需要 wechatUserId + electricUserUid + isAfterMoney）
    var yuResp = '';
    if (wechatUserId) {
      var xhr0 = new XMLHttpRequest();
      xhr0.open('POST', 'http://dfcz.yibinu.edu.cn/kddz/electricmeterpost/electricMeterQuery', false);
      xhr0.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
      xhr0.send('wechatUserId=' + wechatUserId + '&electricUserUid=' + meterId + '&isAfterMoney=' + isAfter);
      yuResp = xhr0.responseText;
    }

    // 接口2: 月度汇总
    var xhr1 = new XMLHttpRequest();
    xhr1.open('POST', 'http://dfcz.yibinu.edu.cn/kddz/electricmeterpost/GetMonthEleAndMoneyList', false);
    xhr1.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
    xhr1.send('meterid=' + meterId + '&startMonth=' + y + '-' + m + '-01&endMonth=' + y + '-' + m + '-01');
    var monthResp = xhr1.responseText;

    // 接口3: 日度明细 (30天)
    var xhr2 = new XMLHttpRequest();
    xhr2.open('POST', 'http://dfcz.yibinu.edu.cn/kddz/electricmeterpost/GetMonthDayEleList', false);
    xhr2.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
    xhr2.send('meterid=' + meterId + '&startTime=' + py + '-' + pm + '-' + pd + '&endTime=' + y + '-' + m + '-' + d);
    var dayResp = xhr2.responseText;

    return JSON.stringify({yu: yuResp, month: monthResp, days: dayResp, wechatUserId: wechatUserId});
  } catch(e) {
    return JSON.stringify({error: e.message});
  }
})();
''';
        try {
          final result = await ctrl.evaluateJavascript(source: js);
          if (result is String && !completer.isCompleted) {
            final data = _parseApiResult(result);
            completer.complete(data);
            return;
          }
        } catch (e) {
          debugPrint('Dianfei WV error: $e');
        }
        if (!completer.isCompleted) completer.complete([]);
      },
    );

    await headless.run();
    final result = await completer.future.timeout(const Duration(seconds: 25), onTimeout: () => []);
    await headless.dispose();
    if (result.isNotEmpty) DataCache().set(cacheKey, result);
    return result;
  }

  List<_DayData> _parseApiResult(String jsonStr) {
    try {
      final wrapper = jsonDecode(jsonStr) as Map;
      if (wrapper.containsKey('error')) return [];

      // 解析余量查询
      final yuBody = wrapper['yu'] as String? ?? '';
      if (yuBody.isNotEmpty) {
        try {
          final yj = jsonDecode(yuBody) as Map;
          if (yj['code'] == 200 && yj['data'] != null) {
            final yd = yj['data'] as Map;
            _shengyu = double.tryParse(yd['shengyu']?.toString() ?? '0') ?? 0;
            _leiji = double.tryParse(yd['leiji']?.toString() ?? '0') ?? 0;
            _zhuangtai = yd['zhuangtai']?.toString() ?? '';
            _price = double.tryParse(yd['price']?.toString() ?? '0.55') ?? 0.55;
            debugPrint('Dianfei yu: 剩余${_shengyu}kWh 累计${_leiji}kWh 状态$_zhuangtai');
          }
        } catch (_) {}
      }

      // 保存微信用户ID
      if (wrapper.containsKey('wechatUserId')) {
        _wechatUserId = wrapper['wechatUserId']?.toString() ?? '';
      }

      // 解析月度汇总
      final monthBody = wrapper['month'] as String? ?? '';
      if (monthBody.isNotEmpty) {
        try {
          final mj = jsonDecode(monthBody) as Map;
          if (mj['code'] == 200 && mj['data'] != null) {
            final md = mj['data']['data'] as List? ?? [];
            if (md.isNotEmpty) {
              final first = md[0] as Map;
              _monthKwh = double.tryParse(first['total']?.toString() ?? '0') ?? 0;
              _monthMoney = double.tryParse(first['money']?.toString() ?? '0') ?? 0;
              _monthStr = first['month']?.toString() ?? '';
              debugPrint('Dianfei month: $_monthStr ${_monthKwh}kWh ¥${_monthMoney}');
            }
          }
        } catch (_) {}
      }

      // 解析日度明细
      final daysBody = wrapper['days'] as String? ?? '';
      if (daysBody.isEmpty) return [];
      final json = jsonDecode(daysBody) as Map;
      if (json['code'] != 200 || json['data'] == null) return [];
      final innerData = json['data'] as Map;
      final list = innerData['data'] as List? ?? [];
      return list.map((e) {
        final m = e as Map;
        return _DayData(
          m['endtime']?.toString()?.substring(5) ?? '',
          double.tryParse(m['total']?.toString() ?? '0') ?? 0,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  Future<void> _unbind() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('解绑电表'),
        content: Text('确定解绑电表 #$_meterId 吗？解绑后可绑定新电表。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('解绑', style: TextStyle(color: Colors.red[600])),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await store.LocalStorage.remove('dianfei_meterId');
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
      _meterId = '';
      _meterCtrl.clear();
    });
    _showSnack('已解绑电表');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
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
                onPressed: _loading ? null : () { DataCache().invalidate('dianfei_$_meterId'); _query(); }),
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
      body: _firstTime ? _buildSetup(isDark) : _buildResult(isDark),
    );
  }

  Widget _buildSetup(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 60),
        Center(child: Icon(Icons.electrical_services_rounded, size: 64, color: _yibinBlue.withValues(alpha: 0.3))),
        const SizedBox(height: 16),
        const Center(child: Text('绑定电表', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
        const SizedBox(height: 8),
        Center(child: Text('输入电表号查询用电量', style: TextStyle(fontSize: 14, color: isDark ? Colors.white60 : Colors.grey[600]))),
        const SizedBox(height: 32),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _meterCtrl,
              decoration: const InputDecoration(labelText: '电表号', hintText: '如：451', border: InputBorder.none),
              keyboardType: TextInputType.number, autofocus: true,
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity, height: 48,
          child: ElevatedButton.icon(
            icon: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.link_rounded, size: 20),
            label: Text(_loading ? '查询中…' : '绑定并查询'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _yibinBlue, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _loading ? null : () { DataCache().invalidate('dianfei_$_meterId'); _query(); },
          ),
        ),
      ],
    );
  }

  Widget _buildResult(bool isDark) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(_error, textAlign: TextAlign.center, style: TextStyle(color: Colors.red[600], fontSize: 13)),
            ),
            const SizedBox(height: 20),
            TextButton.icon(icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('重试'), onPressed: () { DataCache().invalidate('dianfei_$_meterId'); _query(); }),
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
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _yibinBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.electrical_services_rounded, size: 20, color: _yibinBlue),
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
        // 剩余电量卡片
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _shengyu < 20
                  ? [Colors.red[700]!, Colors.red[400]!]
                  : _shengyu < 50
                      ? [Colors.orange[700]!, Colors.orange[400]!]
                      : [_yibinBlue, _yibinBlue.withValues(alpha: 0.7)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('剩余电量', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  if (_zhuangtai.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: _zhuangtai == '合闸' ? Colors.white.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(_zhuangtai, style: const TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${_shengyu.toStringAsFixed(1)}',
                      style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8, left: 4),
                    child: Text('kWh', style: TextStyle(color: Colors.white60, fontSize: 14)),
                  ),
                  const Spacer(),
                  if (_shengyu > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('≈ ¥${(_shengyu * _price).toStringAsFixed(1)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 15)),
                    ),
                ],
              ),
              if (_leiji > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Text('累计用电 ${_leiji.toStringAsFixed(1)} kWh',
                          style: const TextStyle(color: Colors.white60, fontSize: 11)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // 本月汇总卡片
        if (_monthKwh > 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_yibinBlue.withValues(alpha: 0.9), _yibinBlue.withValues(alpha: 0.6)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(_monthStr.isNotEmpty ? '$_monthStr 用电' : '本月用电',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _summaryItem('用电量', '${_monthKwh.toStringAsFixed(1)} kWh'),
                    Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.2)),
                    _summaryItem('电费', '¥${_monthMoney.toStringAsFixed(2)}'),
                  ],
                ),
              ],
            ),
          ),
        if (_monthKwh > 0) const SizedBox(height: 12),
        // 7天/30天 切换
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('近7天'), icon: Icon(Icons.today, size: 16)),
            ButtonSegment(value: 1, label: Text('近30天'), icon: Icon(Icons.date_range, size: 16)),
          ],
          selected: {_viewMode},
          onSelectionChanged: (v) => setState(() => _viewMode = v.first),
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(height: 12),
        // 可切换内容（带动画）
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          child: Column(
            key: ValueKey('view_$_viewMode'),
            children: [
              // 时段汇总卡片
              Container(
                width: double.infinity, padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [_yibinBlue, _yibinBlue.withValues(alpha: 0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text('近${days.length}天用电', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 8),
                    Text('${total.toStringAsFixed(1)} kWh', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('日均 ${avg.toStringAsFixed(1)} kWh · 预估 ¥${(total * _price).toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 折线图
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                  color: isDark ? Colors.grey[850] : Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('每日用电量', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
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
                                  lineColor: _yibinBlue,
                                  fillColor: _yibinBlue.withValues(alpha: 0.12),
                                  gridColor: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                                  dotColor: _yibinBlue,
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
              ),
              const SizedBox(height: 16),
              Text('逐日明细', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 8),
              ...days.reversed.map((d) {
          final ratio = maxKwh > 0 ? d.kwh / maxKwh : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Card(
              elevation: 0,
              color: isDark ? Colors.grey[850] : null,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.withValues(alpha: 0.08))),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    SizedBox(width: 36, child: Text(d.date, style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.grey[700]))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: ratio, minHeight: 6,
                          backgroundColor: _yibinBlue.withValues(alpha: 0.06),
                          valueColor: AlwaysStoppedAnimation<Color>(d.kwh > 15 ? Colors.orange : _yibinBlue.withValues(alpha: 0.7)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(width: 52, child: Text('${d.kwh.toStringAsFixed(1)}', textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87))),
                  ],
                ),
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
                          color: _yibinBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.electrical_services_rounded, size: 20, color: _yibinBlue),
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
                          duration: const Duration(milliseconds: 200),
                          width: (MediaQuery.of(ctx).size.width - 72) / 3,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _yibinBlue.withValues(alpha: 0.15)
                                : _yibinBlue.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? _yibinBlue : _yibinBlue.withValues(alpha: 0.2),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text('¥$amt', style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w700,
                                color: isSelected ? _yibinBlue : _yibinBlue.withValues(alpha: 0.7),
                              )),
                              if (isSelected)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Icon(Icons.check_circle, size: 16, color: _yibinBlue),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity, height: 48,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.receipt_long_rounded, size: 20),
                      label: const Text('生成订单', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedAmount != null ? _yibinBlue : Colors.grey[300],
                        foregroundColor: selectedAmount != null ? Colors.white : Colors.grey[500],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: selectedAmount == null
                          ? null
                          : () {
                              Navigator.pop(ctx);
                              _doRecharge(selectedAmount!);
                            },
                    ),
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
      final paymentId = await _createRechargeOrder(amount);
      if (paymentId == null || !mounted) return;

      final payUrl = 'http://dfcz.yibinu.edu.cn/electricmeter/index.html'
          '#/pages/meterlist/meterpayconfirm'
          '?paymentId=$paymentId&wechatUserOpenid=oBY1y5qCDUCD1muCFD8lblZIOXr8&meterId=$_meterId';

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
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[600], size: 24),
              const SizedBox(width: 10),
              const Text('订单已创建', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _yibinBlue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('充值金额', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                        Text('¥${amount.toStringAsFixed(0)}', style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold, color: _yibinBlue,
                        )),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('电表 #$_meterId', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('支付链接', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  payUrl,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  maxLines: 3, overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.wechat_rounded, size: 20),
                  label: const Text('复制并打开微信', style: TextStyle(fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF07C160),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                    launchUrl(Uri.parse('weixin://'), mode: LaunchMode.externalApplication);
                    Navigator.pop(ctx);
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('关闭', style: TextStyle(color: Colors.grey[600])),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _createRechargeOrder(double amount) async {
    final completer = Completer<String?>();
    final url = 'http://dfcz.yibinu.edu.cn/electricmeter/index.html'
        '#/pages/meterlist/meterpay'
        '?wechatUserOpenid=oBY1y5qCDUCD1muCFD8lblZIOXr8&meterId=$_meterId';

    bool started = false;

    final headless = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true, domStorageEnabled: true,
        userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36',
      ),
      onLoadStop: (ctrl, _) async {
        if (started) return;
        started = true;

        await Future.delayed(const Duration(seconds: 4));
        if (completer.isCompleted) return;

        final money = amount.toStringAsFixed(0);
    final js = r'''
(function() {
  try {
    var meterId = (location.href.match(/meterId=(\d+)/) || ['',''])[1];
    var openId = (location.href.match(/wechatUserOpenid=([^&]+)/) || ['',''])[1];

    // 获取微信用户信息
    var xhr0 = new XMLHttpRequest();
    xhr0.open('POST', 'http://dfcz.yibinu.edu.cn/kddz/electricmeterpost/index', false);
    xhr0.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
    xhr0.send('openId=' + openId);
    var userResp = JSON.parse(xhr0.responseText);
    var wechatUserId = '';
    if (userResp.code == 200 && userResp.data) {
      wechatUserId = userResp.data.wechatId;
    }
    if (!wechatUserId) return JSON.stringify({error: '获取用户信息失败'});

    // 创建充值订单
    var xhr1 = new XMLHttpRequest();
    xhr1.open('POST', 'http://dfcz.yibinu.edu.cn/kddz/electricmeterpost/electricCrteatementPay', false);
    xhr1.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
    xhr1.send('wechatUserId=' + wechatUserId + '&electricUserUid=' + meterId + '&money=__MONEY__');
    var payResp = JSON.parse(xhr1.responseText);
    if (payResp.code == 200 && payResp.data) {
      return JSON.stringify({paymentId: payResp.data.paymentId});
    }
    return JSON.stringify({error: payResp.msg || '创建订单失败'});
  } catch(e) {
    return JSON.stringify({error: e.message});
  }
})();
'''.replaceAll('__MONEY__', money);

        try {
          final result = await ctrl.evaluateJavascript(source: js);
          if (result is String && !completer.isCompleted) {
            final parsed = jsonDecode(result) as Map;
            if (parsed.containsKey('error')) {
              debugPrint('Recharge API error: ${parsed['error']}');
              completer.complete(null);
            } else {
              completer.complete(parsed['paymentId']?.toString());
            }
            return;
          }
        } catch (e) {
          debugPrint('Recharge WV error: $e');
        }
        if (!completer.isCompleted) completer.complete(null);
      },
    );

    await headless.run();
    final result = await completer.future.timeout(const Duration(seconds: 20), onTimeout: () => null);
    await headless.dispose();
    return result;
  }

  @override
  void dispose() {
    _meterCtrl.dispose();
    super.dispose();
  }

  Widget _summaryItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
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
