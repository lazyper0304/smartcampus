import 'package:flutter/material.dart';

import '../main.dart';

/// 校园网角标（用于「服务」网格入口卡的右上角）。
///
/// 不占用卡片主体布局，仅以实心小胶囊提示该应用需校园内网访问。
class OfficeCampusCornerBadge extends StatelessWidget {
  const OfficeCampusCornerBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final accent = accentColorNotifier.value;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lan_rounded, size: 9, color: Colors.white),
          const SizedBox(width: 2),
          const Text(
            '校园网',
            style: TextStyle(
              fontSize: 9,
              color: Colors.white,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// 校园网标识（行内胶囊，用于列表卡片与详情页）。
///
/// 办公网（off.yibinu.edu.cn）仅能在校内网/内网环境访问与打开，
/// 统一展示该标识提醒用户处于内网环境，避免在校外直接点击时因网络不可达而困惑。
class OfficeCampusBadge extends StatelessWidget {
  const OfficeCampusBadge({super.key, this.size = 12});

  /// 图标与字号基准大小，紧凑场景可调小
  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = accentColorNotifier.value;
    return Tooltip(
      message: '需连接校园内网（off.yibinu.edu.cn）才能访问',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: accent.withValues(alpha: 0.35),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lan_rounded, size: size, color: accent),
            const SizedBox(width: 3),
            Text(
              '校园网',
              style: TextStyle(
                fontSize: size * 0.9,
                fontWeight: FontWeight.w600,
                color: accent,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
