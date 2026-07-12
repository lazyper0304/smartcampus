import 'package:flutter/material.dart';
import 'package:cue/cue.dart';

import '../core/http_client.dart';
import '../core/local_storage.dart';
import '../core/navigation.dart';
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
    with TickerProviderStateMixin {
  late final CueController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = CueController(vsync: this, motion: .smooth());
    _animCtrl.repeat(reverse: true);
    _fetchInfo();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchInfo() async {
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D47A1), Color(0xFF002171)],
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
                  final pulse = _animCtrl.value;
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
