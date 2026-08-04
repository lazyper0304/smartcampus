/// 电费查询模块数据模型（与 UI 解耦，由 DianfeiService 产出）。

library;

/// 单日电度明细
class DayData {
  final String date;
  final double kwh;

  const DayData(this.date, this.kwh);
}

/// 电表状态与月度汇总（查询结果附带 + 本地缓存复用）
class DianfeiStatus {
  final double shengyu; // 剩余电量
  final double leiji; // 累计用电
  final String zhuangtai; // 当前状态（合闸/分闸）
  final double price; // 电价
  final double monthKwh; // 本月用电
  final double monthMoney; // 本月金额
  final String monthStr; // 本月标识
  final String wechatUserId; // 微信用户ID（充值用）

  const DianfeiStatus({
    this.shengyu = 0,
    this.leiji = 0,
    this.zhuangtai = '',
    this.price = 0.55,
    this.monthKwh = 0,
    this.monthMoney = 0,
    this.monthStr = '',
    this.wechatUserId = '',
  });

  static const empty = DianfeiStatus();
}

/// 一次查询的完整结果
class DianfeiQueryResult {
  final List<DayData> days;
  final DianfeiStatus status;

  const DianfeiQueryResult(this.days, this.status);
}
