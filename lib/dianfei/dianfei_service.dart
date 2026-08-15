import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../core/data_cache.dart';
import '../core/local_storage.dart' as store;
import 'dianfei_models.dart';

/// 电费查询服务：封装临港电费系统的全部请求逻辑
/// （HeadlessInAppWebView 模拟浏览器 + 站内 XHR 抓取、解析、充值下单、缓存），
/// 页面只调本服务并渲染结果。
class DianfeiService {
  DianfeiService._();

  static const _base = 'http://dfcz.yibinu.edu.cn';
  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36';

  /// 从查询链接提取 wechatUserOpenid 与 meterId；格式不合法返回 null。
  static ({String openId, String meterId})? parseLink(String raw) {
    final openIdMatch =
        RegExp(r'[?&]wechatUserOpenid=([^&]+)').firstMatch(raw);
    final meterIdMatch = RegExp(r'[?&]meterId=(\d+)').firstMatch(raw);
    if (openIdMatch == null || meterIdMatch == null) return null;
    return (
      openId: Uri.decodeComponent(openIdMatch.group(1)!),
      meterId: meterIdMatch.group(1)!,
    );
  }

  /// 查询电表数据（余量 + 月度汇总 + 30 天日度明细），失败抛异常。
  static Future<DianfeiQueryResult> query({
    required String meterId,
    required String wechatUserOpenid,
  }) async {
    final cacheKey = 'dianfei_$meterId';
    final cached = DataCache().get<DianfeiQueryResult>(cacheKey);
    if (cached != null) return cached;

    final completer = Completer<DianfeiQueryResult>();
    final url = '$_base/electricmeter/index.html'
        '#/pages/meterlist/meterqueryChart'
        '?wechatUserOpenid=$wechatUserOpenid&meterId=$meterId';

    bool started = false;

    final headless = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        userAgent: _userAgent,
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
            completer.complete(_parseApiResult(result));
            return;
          }
        } catch (e) {
          debugPrint('Dianfei WV error: $e');
        }
        if (!completer.isCompleted) {
          completer.complete(const DianfeiQueryResult([], DianfeiStatus.empty));
        }
      },
    );

    await headless.run();
    final result = await completer.future
        .timeout(const Duration(seconds: 25),
            onTimeout: () =>
                const DianfeiQueryResult([], DianfeiStatus.empty));
    await headless.dispose();
    if (result.days.isNotEmpty) DataCache().set(cacheKey, result);
    return result;
  }

  /// 充值下单，返回 paymentId；失败返回 null。
  static Future<String?> createRechargeOrder({
    required String meterId,
    required String wechatUserOpenid,
    required double amount,
  }) async {
    final completer = Completer<String?>();
    final url = '$_base/electricmeter/index.html'
        '#/pages/meterlist/meterpay'
        '?wechatUserOpenid=$wechatUserOpenid&meterId=$meterId';

    bool started = false;

    final headless = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        userAgent: _userAgent,
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
    final result = await completer.future
        .timeout(const Duration(seconds: 20), onTimeout: () => null);
    await headless.dispose();
    return result;
  }

  /// 解析 WebView 内 JS 返回的三接口聚合结果。
  static DianfeiQueryResult _parseApiResult(String jsonStr) {
    try {
      final wrapper = jsonDecode(jsonStr) as Map;
      if (wrapper.containsKey('error')) {
        return const DianfeiQueryResult([], DianfeiStatus.empty);
      }

      var status = DianfeiStatus.empty;

      // 解析余量查询
      final yuBody = wrapper['yu'] as String? ?? '';
      if (yuBody.isNotEmpty) {
        try {
          final yj = jsonDecode(yuBody) as Map;
          if (yj['code'] == 200 && yj['data'] != null) {
            final yd = yj['data'] as Map;
            status = DianfeiStatus(
              shengyu: double.tryParse(yd['shengyu']?.toString() ?? '0') ?? 0,
              leiji: double.tryParse(yd['leiji']?.toString() ?? '0') ?? 0,
              zhuangtai: yd['zhuangtai']?.toString() ?? '',
              price: double.tryParse(yd['price']?.toString() ?? '0.55') ?? 0.55,
            );
          }
        } catch (_) {}
      }

      // 微信用户ID
      if (wrapper.containsKey('wechatUserId')) {
        status = DianfeiStatus(
          shengyu: status.shengyu,
          leiji: status.leiji,
          zhuangtai: status.zhuangtai,
          price: status.price,
          wechatUserId: wrapper['wechatUserId']?.toString() ?? '',
        );
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
              status = DianfeiStatus(
                shengyu: status.shengyu,
                leiji: status.leiji,
                zhuangtai: status.zhuangtai,
                price: status.price,
                wechatUserId: status.wechatUserId,
                monthKwh: double.tryParse(first['total']?.toString() ?? '0') ?? 0,
                monthMoney: double.tryParse(first['money']?.toString() ?? '0') ?? 0,
                monthStr: first['month']?.toString() ?? '',
              );
            }
          }
        } catch (_) {}
      }

      // 解析日度明细
      final daysBody = wrapper['days'] as String? ?? '';
      if (daysBody.isEmpty) return DianfeiQueryResult([], status);
      final json = jsonDecode(daysBody) as Map;
      if (json['code'] != 200 || json['data'] == null) {
        return DianfeiQueryResult([], status);
      }
      final innerData = json['data'] as Map;
      final list = innerData['data'] as List? ?? [];
      final days = list.map((e) {
        final m = e as Map;
        return DayData(
          m['endtime']?.toString().substring(5) ?? '',
          double.tryParse(m['total']?.toString() ?? '0') ?? 0,
        );
      }).toList();
      return DianfeiQueryResult(days, status);
    } catch (_) {
      return const DianfeiQueryResult([], DianfeiStatus.empty);
    }
  }

  // ── 本地缓存（剩余电量/月度汇总，下次进入快速恢复） ──

  /// 从本地缓存恢复电表状态。
  static Future<DianfeiStatus> loadSummary() async {
    final shengyu = await store.LocalStorage.getString('dianfei_shengyu');
    if (shengyu == null) return DianfeiStatus.empty;
    final leiji = await store.LocalStorage.getString('dianfei_leiji');
    final zhuangtai = await store.LocalStorage.getString('dianfei_zhuangtai');
    final price = await store.LocalStorage.getString('dianfei_price');
    final monthKwh = await store.LocalStorage.getString('dianfei_monthKwh');
    final monthMoney = await store.LocalStorage.getString('dianfei_monthMoney');
    final monthStr = await store.LocalStorage.getString('dianfei_monthStr');
    return DianfeiStatus(
      shengyu: double.tryParse(shengyu) ?? 0,
      leiji: double.tryParse(leiji ?? '0') ?? 0,
      zhuangtai: zhuangtai ?? '',
      price: double.tryParse(price ?? '0.55') ?? 0.55,
      monthKwh: double.tryParse(monthKwh ?? '0') ?? 0,
      monthMoney: double.tryParse(monthMoney ?? '0') ?? 0,
      monthStr: monthStr ?? '',
    );
  }

  /// 缓存电表状态到本地。
  static Future<void> saveSummary(DianfeiStatus s) async {
    await store.LocalStorage.setString('dianfei_shengyu', s.shengyu.toString());
    await store.LocalStorage.setString('dianfei_leiji', s.leiji.toString());
    await store.LocalStorage.setString('dianfei_zhuangtai', s.zhuangtai);
    await store.LocalStorage.setString('dianfei_price', s.price.toString());
    await store.LocalStorage.setString('dianfei_monthKwh', s.monthKwh.toString());
    await store.LocalStorage.setString('dianfei_monthMoney', s.monthMoney.toString());
    await store.LocalStorage.setString('dianfei_monthStr', s.monthStr);
  }

  // ── 电费数据长期缓存（获取一次长期存储，仅手动刷新重新获取） ──

  /// 缓存每日用电明细（JSON 数组）
  static Future<void> saveDays(List<DayData> days) async {
    await store.LocalStorage.setString(
      'dianfei_days',
      jsonEncode(days.map((d) => {'date': d.date, 'kwh': d.kwh}).toList()),
    );
  }

  /// 恢复每日用电明细
  static Future<List<DayData>> loadDays() async {
    final raw = await store.LocalStorage.getString('dianfei_days');
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => DayData(
                (e as Map)['date']?.toString() ?? '',
                ((e as Map)['kwh'] as num?)?.toDouble() ?? 0,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 记录最后获取时间（页面显示"数据获取于"）
  static Future<void> saveUpdatedAt(String formatted) async {
    await store.LocalStorage.setString('dianfei_updatedAt', formatted);
  }

  static Future<String> loadUpdatedAt() async {
    return await store.LocalStorage.getString('dianfei_updatedAt') ?? '';
  }

  /// 是否已有本地缓存（首次查询后置 1）
  static Future<bool> hasCache() async {
    return await store.LocalStorage.getString('dianfei_cached') == '1';
  }

  static Future<void> markCached() async {
    await store.LocalStorage.setString('dianfei_cached', '1');
  }
}
