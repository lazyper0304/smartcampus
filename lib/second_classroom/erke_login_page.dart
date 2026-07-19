import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../core/local_storage.dart';
import '../core/simple_page.dart';
import '../core/theme_utils.dart';
import '../main.dart';
import 'erke_page.dart';
import 'erke_service.dart';

/// 第二课堂独立登录页（与智慧校园 / CAS 无关）。
///
/// - 点击「第二课堂」卡片直接进入本页（无中间过渡页）
/// - 支持「记住密码」：勾选后本地保存密码，下次进入自动预填（不自动登录）
/// - 登录成功后把 token 与 username 存入本地，并替换进入成绩页
class ErkeLoginPage extends StatefulWidget {
  const ErkeLoginPage({super.key});

  @override
  State<ErkeLoginPage> createState() => _ErkeLoginPageState();
}

class _ErkeLoginPageState extends State<ErkeLoginPage> {
  final _userCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscure = true;
  bool _remember = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  // 预填已保存的账号密码（仅预填，不自动登录）
  Future<void> _loadSaved() async {
    final user = await LocalStorage.getString('erke_username');
    final pwd = await LocalStorage.getString('erke_password');
    if (!mounted) return;
    setState(() {
      if (user != null && user.isNotEmpty) _userCtrl.text = user;
      if (pwd != null && pwd.isNotEmpty) {
        _pwdCtrl.text = pwd;
        _remember = true;
      }
    });
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final user = _userCtrl.text.trim();
    final pwd = _pwdCtrl.text;
    if (user.isEmpty || pwd.isEmpty) {
      setState(() => _error = '请输入学号与密码');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await ErkeService.login(user, pwd);
      await LocalStorage.setString('erke_token', token);
      await LocalStorage.setString('erke_username', user);
      // 记住密码：保存或清除本地密码
      if (_remember) {
        await LocalStorage.setString('erke_password', pwd);
      } else {
        await LocalStorage.remove('erke_password');
      }
      if (!mounted) return;
      // 登录成功直接进入成绩页（替换登录页，返回即退出模块，无中间页）
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ErkePage()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = accentColorNotifier.value;
    return SimplePage(
      statusBarStyle: GlassStatusBarStyle.auto,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('第二课堂登录'),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.assignment_ind_rounded,
                    color: accent, size: 28),
              ),
              const SizedBox(height: 16),
              Text('第二课堂',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('使用第二课堂账号密码登录（与智慧校园相互独立）',
                  style: TextStyle(
                      fontSize: 13, color: textSecondary(context))),
              const SizedBox(height: 20),
              // 初始密码格式提示
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: accent.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 16, color: accent),
                        const SizedBox(width: 6),
                        Text('初始密码格式',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: accent)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('学号 + @10641 + Yibin',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3)),
                    const SizedBox(height: 2),
                    Text('例：222222222@10641Yibin',
                        style: TextStyle(
                            fontSize: 12,
                            color: textSecondary(context))),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _userCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '学号',
                  prefixIcon: const Icon(Icons.person_rounded),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _pwdCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: '密码',
                  prefixIcon: const Icon(Icons.lock_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onSubmitted: (_) => _login(),
              ),
              // 记住密码
              Row(
                children: [
                  Checkbox(
                    value: _remember,
                    activeColor: accent,
                    onChanged: (v) => setState(() => _remember = v ?? false),
                  ),
                  const Text('记住密码', style: TextStyle(fontSize: 13)),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(_error!,
                    style: const TextStyle(fontSize: 13, color: Colors.red)),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('登录', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),
              Text('提示：本系统仅校园内网可访问，请确保在校园网环境下登录。',
                  style: TextStyle(
                      fontSize: 12, color: textHint(context))),
            ],
          ),
        ),
      ),
    );
  }
}
