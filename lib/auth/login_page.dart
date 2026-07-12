import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cue/cue.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../core/local_storage.dart';
import '../core/navigation.dart';
import '../home/main_screen.dart';
import '../xuegong/student_info_manager.dart';
import 'auth_service.dart';

const Color _yibinBlue = Color.fromRGBO(25, 25, 153, 1);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberPassword = false;

  late final CueController _flowCtrl;

  @override
  void initState() {
    super.initState();
    _flowCtrl = CueController(
      vsync: this,
      motion: .linear(const Duration(seconds: 6)),
    )..repeat(reverse: true);
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _flowCtrl.dispose();
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
    if (_rememberPassword) {
      await LocalStorage.setString('username', _usernameController.text.trim());
      await LocalStorage.setString('password', _passwordController.text);
      await LocalStorage.setBool('remember_password', true);
    } else {
      await LocalStorage.remove('username');
      await LocalStorage.remove('password');
      await LocalStorage.setBool('remember_password', false);
    }
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

      // 等待获取个人信息后再进入应用
      if (!mounted) return;
      setState(() => _isLoading = true);
      await StudentInfoManager.fetchUntilSuccess(_authService.client);

      if (!mounted) return;

      replacePage(context, MainScreen(
        client: _authService.client,
        userId: _usernameController.text.trim(),
      ), acts: const [Act.fadeIn(), Act.scale(from: 0.92)]);
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassScaffold(
      background: ListenableBuilder(
        listenable: _flowCtrl,
        builder: (context, _) {
          final flow = _flowCtrl.value;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(
                    const Color(0xFF0D47A1),
                    const Color(0xFF1565C0),
                    flow,
                  )!,
                  Color.lerp(
                    const Color(0xFF002171),
                    const Color(0xFF0D47A1),
                    flow,
                  )!,
                  Color.lerp(
                    const Color(0xFF1A237E),
                    const Color(0xFF002171),
                    flow,
                  )!,
                ],
              ),
            ),
          );
        },
      ),
      statusBarStyle: GlassStatusBarStyle.light,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Cue.onMount(
              motion: .smooth(),
              acts: [.fadeIn(), .slideY(from: 0.15)],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 24),
                  const Text(
                    '宜院宾果',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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
    );
  }

  Widget _buildLoginCard(ColorScheme colorScheme) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
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
                  icon: Cue.onChange(
                    value: _obscurePassword,
                    motion: .snappy(),
                    acts: [.fadeIn()],
                    child: _obscurePassword
                        ? const Icon(Icons.visibility_off_rounded)
                        : const Icon(Icons.visibility_rounded),
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
                  backgroundColor: _yibinBlue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _yibinBlue.withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Cue.onChange(
                  value: _isLoading,
                  motion: .snappy(),
                  acts: [.fadeIn(), .scale(from: 0.9)],
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
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
          ],
        ),
        ),
      ),
    );
  }
}
