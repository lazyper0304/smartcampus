import 'package:flutter/material.dart';

/// 纯淡入页面转场 — 无任何滑动/缩放动画
const Duration _duration = Duration(milliseconds: 350);

PageRouteBuilder _fadeRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) {
      return FadeTransition(
        opacity: animation,
        child: page,
      );
    },
    transitionDuration: _duration,
    reverseTransitionDuration: const Duration(milliseconds: 300),
  );
}

/// Push a new page with fade transition.
void pushPage(BuildContext context, Widget page) {
  Navigator.push(context, _fadeRoute(page));
}

/// Replace the current page (splash → main/login).
void replacePage(BuildContext context, Widget page) {
  Navigator.pushReplacement(context, _fadeRoute(page));
}

/// Push and remove all previous routes (logout).
void pushAndClear(BuildContext context, Widget page) {
  Navigator.pushAndRemoveUntil(
    context,
    _fadeRoute(page),
    (route) => false,
  );
}
