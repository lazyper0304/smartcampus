import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 余额金额（¥ + 数字同一套圆角数字字体，对齐 Apple 钱包）
class EcardBalanceAmount extends StatelessWidget {
  const EcardBalanceAmount({
    super.key,
    required this.amount,
    required this.color,
  });

  final double amount;
  final Color color;

  static String get _fontFamily {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return '.SF Pro Rounded';
      default:
        return 'Roboto';
    }
  }

  static const _fallback = ['SF Pro Rounded', '.SF Pro Text'];

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      inherit: false,
      fontFamily: _fontFamily,
      fontFamilyFallback: _fallback,
      fontSize: 34,
      fontWeight: FontWeight.w700,
      color: color,
      letterSpacing: -0.8,
      height: 1.05,
      decoration: TextDecoration.none,
    );

    return Text.rich(
      TextSpan(
        style: style,
        children: [
          const TextSpan(text: '¥'),
          TextSpan(text: amount.toStringAsFixed(2)),
        ],
      ),
    );
  }
}
