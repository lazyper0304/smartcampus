import 'package:flutter/material.dart';
import 'dart:async';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../core/guest_mode.dart';
import '../core/ios_kit.dart';
import '../core/local_storage.dart';
import '../core/navigation.dart';
import '../home/main_screen.dart';
import '../splash/fetch_info_page.dart';
import '../xuegong/student_info_manager.dart';
import 'auth_service.dart';
import '../core/liquid_background.dart';
import '../main.dart';

Color get _accentBlue => accentColorNotifier.value;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _obscurePassword = true;
  bool _isLoading = false;

  /// 默认勾选"记住密码"：凭据总是会保存用于会话自动续期，
  /// 该标志仅决定下次打开登录页时是否自动填充账号密码。
  bool _rememberPassword = true;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    final savedUsername = await LocalStorage.getString('username') ?? '';
    final savedPassword = await LocalStorage.getString('password') ?? '';
    final savedRemember = await LocalStorage.getBool('remember_password');

    if (savedRemember && savedUsername.isNotEmpty) {
      _usernameController.text = savedUsername;
      _passwordController.text = savedPassword;
      setState(() => _rememberPassword = true);
    }
  }

  Future<void> _saveCredentials() async {
    // 凭据总是保存：登录成功后本地始终有账号密码，会话过期时
    // AuthService.autoRelogin 才能静默重登（用户无需手动重新登录）。
    // remember_password 仅控制下次打开登录页是否自动填充。
    await LocalStorage.setString('username', _usernameController.text.trim());
    await LocalStorage.setString('password', _passwordController.text);
    await LocalStorage.setBool('remember_password', _rememberPassword);
  }

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);

    final result = await _authService.login(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      // 保存登录凭据和会话 Cookie
      await _saveCredentials();
      await _authService.client.saveCookies();
      await LocalStorage.setString('saved_username', _usernameController.text.trim());
      // 正常登录成功，退出游客模式
      await GuestMode.exit();

      if (!mounted) return;

      // 有缓存则直接进主页面；首次登录需先获取个人信息（FetchInfoPage 阻塞）
      final cached = await StudentInfoManager.getCached();
      if (!mounted) return;
      if (cached != null) {
        replacePage(
          context,
          MainScreen(client: _authService.client, userId: _usernameController.text.trim()),
        );
      } else {
        replacePage(context, FetchInfoPage(client: _authService.client));
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// 游客登录：无需账号密码，仅可使用无需登录的功能
  Future<void> _handleGuestLogin() async {
    if (_isLoading) return;
    await GuestMode.enter();
    if (!mounted) return;
    replacePage(
      context,
      MainScreen(client: _authService.client, userId: ''),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassScaffold(
      // 与主界面同款的统一液态玻璃背景（主题渐变 + 动态气泡）
      background: const LiquidBackground(),
      statusBarStyle: GlassStatusBarStyle.auto,
      // 透明 Scaffold：提供 Material 祖先（TextField/Checkbox 需要）+ 
      // SnackBar 宿主（0.26.0 起 GlassScaffold 内部是 CupertinoPageScaffold，
      // 无 Material Scaffold 注册，登录失败提示 SnackBar 无法显示）。
      body: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 30 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 24),
                    Text(
                      '宜院宾果',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        // 跟随主题（浅色深字 / 深色浅字），不再固定白色
                        color: colorScheme.onSurface,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 48),
                    _buildLoginCard(colorScheme),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard(ColorScheme colorScheme) {
    // iOS 毛玻璃登录卡片：BackdropFilter 半透明白 + 模糊（全设备有效，
    // GlassCard shader 在 GLES 设备不渲染）；透明 Material 提供表单祖先。
    return contentCardGlass(
      context: context,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _usernameController,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '学号/工号',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '请输入学号或工号' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _handleLogin(),
              decoration: InputDecoration(
                labelText: '密码',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                    child: _obscurePassword
                        ? const Icon(Icons.visibility_off_rounded, key: ValueKey('off'))
                        : const Icon(Icons.visibility_rounded, key: ValueKey('on')),
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) => (v == null || v.isEmpty) ? '请输入密码' : null,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                SizedBox(
                  height: 44,
                  child: Checkbox(
                    value: _rememberPassword,
                    onChanged: (v) =>
                        setState(() => _rememberPassword = v ?? false),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                GestureDetector(
                  onTap: () =>
                      setState(() => _rememberPassword = !_rememberPassword),
                  child: Text('记住密码',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentBlue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _accentBlue.withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: animation, child: child),
                    );
                  },
                  child: _isLoading
                      ? const SizedBox(key: ValueKey('loading'), width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : const Row(
                          key: ValueKey('login'),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.login_rounded, size: 20),
                            SizedBox(width: 8),
                            Text('登  录',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 2,
                                )),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                '使用统一认证登录',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey.withValues(alpha: 0.2))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('或',
                      style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                ),
                Expanded(child: Divider(color: Colors.grey.withValues(alpha: 0.2))),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _handleGuestLogin,
                icon: Icon(Icons.person_outline_rounded,
                    size: 18, color: _accentBlue),
                label: Text(
                  '游客登录',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _accentBlue,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _accentBlue.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '游客模式仅可使用无需登录的功能',
                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
