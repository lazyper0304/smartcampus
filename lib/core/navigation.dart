import 'package:flutter/cupertino.dart';

/// iOS 风格页面切换动画（CupertinoPageRoute）：
/// - 右滑推入 + 下层视差 + 上层轻微缩放（iOS 系统标准转场，400ms）
/// - 支持 iOS 边缘左滑返回手势（interactive pop）
CupertinoPageRoute<T> _buildRoute<T>(Widget page) {
  return CupertinoPageRoute<T>(
    builder: (_) => page,
  );
}

/// Push a new page.
void pushPage(BuildContext context, Widget page) {
  Navigator.push(context, _buildRoute(page));
}

/// Push a new page and await its popped result.
Future<T?> pushPageForResult<T>(BuildContext context, Widget page) {
  return Navigator.push<T>(context, _buildRoute<T>(page));
}

/// Replace the current page (splash → main/login).
void replacePage(BuildContext context, Widget page) {
  Navigator.pushReplacement(context, _buildRoute(page));
}

/// Push and remove all previous routes (logout).
void pushAndClear(BuildContext context, Widget page) {
  Navigator.pushAndRemoveUntil(
    context,
    _buildRoute(page),
    (route) => false,
  );
}
