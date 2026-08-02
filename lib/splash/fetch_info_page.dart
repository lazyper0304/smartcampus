import 'package:flutter/material.dart';

import '../core/http_client.dart';
import '../core/local_storage.dart';
import '../core/navigation.dart';
import '../main.dart';
import '../home/main_screen.dart';
import '../xuegong/student_info_manager.dart';

/// 获取个人信息过渡页面 — 首次进入时展示
class FetchInfoPage extends StatefulWidget {
  final SharedHttpClient client;

  const FetchInfoPage({super.key, required this.client});

  @override
  State<FetchInfoPage> createState() => _FetchInfoPageState();
}

class _FetchInfoPageState extends State<FetchInfoPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut),
    );
    _animCtrl.repeat(reverse: true);
    _fetchInfo();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchInfo() async {
    // 1. 检查缓存，已有则直接跳转（cookie 失效也不用重新获取）
    final cached = await StudentInfoManager.getCached();
    if (cached != null) {
      if (!mounted) return;
      final savedUser = await LocalStorage.getString('saved_username') ?? '';
      if (!mounted) return;
      replacePage(context, MainScreen(client: widget.client, userId: savedUser));
      return;
    }

    // 2. 等待 2 秒让 CAS session 完全生效、学工页面加载完成
    await Future.delayed(const Duration(seconds: 2));

    // 3. 持续重试获取个人信息
    await StudentInfoManager.fetchUntilSuccess(widget.client);
    if (!mounted) return;

    final savedUser = await LocalStorage.getString('saved_username') ?? '';
    if (!mounted) return;

    replacePage(
      context,
      MainScreen(client: widget.client, userId: savedUser),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accentColorNotifier.value,
              Color.lerp(accentColorNotifier.value, const Color(0xFF002171), 0.6)!,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 呼吸灯图标
              ListenableBuilder(
                listenable: _animCtrl,
                builder: (context, _) {
                  final pulse = _pulseAnim.value;
                  return Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1 + pulse * 0.1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      Icons.person_outline_rounded,
                      size: 44,
                      color: Colors.white.withValues(alpha: 0.7 + pulse * 0.3),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text(
                '宜院宾果',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '正在获取个人信息…',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.6),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
