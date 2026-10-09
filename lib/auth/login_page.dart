import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../core/bingo/bingo_client.dart';
import '../core/guest_mode.dart';
import '../core/ios_kit.dart';
import '../core/local_storage.dart';
import '../core/navigation.dart';
import '../home/main_screen.dart';
import '../splash/fetch_info_page.dart';
import '../xuegong/student_info_manager.dart';
import 'auth_service.dart';
import 'beginner_login_page.dart';
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
  final _captchaController = TextEditingController();
  final _authService = AuthService();

  bool _obscurePassword = true;
  bool _isLoading = false;

  /// 图形验证码挑战载荷（Bingo `/auth/login` 下发）。
  /// 为 null 表示当前不需要验证码，登录卡片不显示该输入框。
  LoginCaptchaChallenge? _captcha;

  /// 学号输入防抖定时器：连输时不打 `/captcha-status`
  Timer? _captchaDebounce;

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
    _captchaDebounce?.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    _captchaController.dispose();
    super.dispose();
  }

  // ==================== 图形验证码 ====================

  /// 学号变化后防抖查询是否需要验证码
  void _onUsernameChanged(String value) {
    _captchaDebounce?.cancel();
    final id = value.trim();
    if (id.isEmpty) {
      if (_captcha != null) {
        setState(() {
          _captcha = null;
          _captchaController.clear();
        });
      }
      return;
    }
    _captchaDebounce = Timer(const Duration(milliseconds: 600), () {
      _queryCaptcha(id);
    });
  }

  Future<void> _queryCaptcha(String schoolId) async {
    try {
      final status = await _authService.queryCaptchaStatus(schoolId);
      if (!mounted) return;
      // 后端判定无需验证码时 captcha_required=false
      if (status.captchaRequired) {
        await _refreshCaptcha(schoolId);
      } else if (_captcha != null) {
        setState(() {
          _captcha = null;
          _captchaController.clear();
        });
      }
    } catch (_) {
      // 预检失败不阻断登录：真正提交时后端仍会返回挑战
    }
  }

  /// 拉取/刷新验证码图片
  Future<void> _refreshCaptcha([String? schoolId]) async {
    final id = schoolId ?? _usernameController.text.trim();
    if (id.isEmpty) return;
    try {
      final c = await _authService.fetchCaptcha(id);
      if (!mounted) return;
      setState(() {
        _captcha = c;
        _captchaController.clear();
      });
    } catch (_) {
      // 图片拉取失败保持原状，用户仍可直接提交由后端判定
    }
  }

  /// 渲染验证码图片（支持 data URI 与裸 base64 两种形态）
  Widget _buildCaptchaRow() {
    final c = _captcha;
    if (c == null) return const SizedBox.shrink();
    final uri = _captchaImageUri(c.captchaImage);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextFormField(
              controller: _captchaController,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _handleLogin(),
              decoration: const InputDecoration(
                labelText: '验证码',
                prefixIcon: Icon(Icons.verified_outlined),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? '请输入验证码' : null,
            ),
          ),
          const SizedBox(width: 10),
          _CaptchaImage(
            uri: uri,
            onRefresh: () => _refreshCaptcha(),
          ),
        ],
      ),
    );
  }

  /// 兼容 `data:image/png;base64,...` 与裸 base64 两种下发形态
  static String? _captchaImageUri(String? raw) {
    final s = raw?.trim() ?? '';
    if (s.isEmpty) return null;
    if (s.startsWith('data:')) return s;
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    return 'data:image/png;base64,$s';
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
      captchaId: _captcha?.captchaId,
      captchaCode: _captchaController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    // 登录失败但后端下发了验证码挑战 → 渲染验证码输入框让用户重填
    if (!result.success && result.challenge != null) {
      setState(() {
        _captcha = result.challenge;
        _captchaController.clear();
      });
    }

    if (result.success) {
      // 保存登录凭据和会话 Cookie
      await _saveCredentials();
      await _authService.client.saveCookies();
      await LocalStorage.setString('saved_username', _usernameController.text.trim());
      // 登录成功，退出游客模式
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

  /// 跳转新生模式独立登录页（该页无游客模式选项，顶部常驻提示）。
  void _handleBeginnerLogin() {
    if (_isLoading) return;
    pushPage(context, const BeginnerLoginPage());
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
            // 大屏（平板/桌面）下登录卡片限宽 480 居中，避免表单拉伸过宽
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
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
              onChanged: _onUsernameChanged,
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
            _buildCaptchaRow(),
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
            const SizedBox(height: 14),
            SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _handleBeginnerLogin,
                icon: Icon(Icons.school_rounded,
                    size: 18, color: _accentBlue),
                label: Text(
                  '新生模式',
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
                '已录入智慧校园，但个人信息暂未补全',
                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 验证码图片（点击可刷新）
class _CaptchaImage extends StatelessWidget {
  final String? uri;
  final VoidCallback onRefresh;

  const _CaptchaImage({required this.uri, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '点击刷新验证码',
      child: InkWell(
        onTap: onRefresh,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 116,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey[300]!),
          ),
          clipBehavior: Clip.antiAlias,
          alignment: Alignment.center,
          child: uri == null
              ? const Icon(Icons.refresh_rounded,
                  size: 20, color: Colors.grey)
              : Image.memory(
                  _decodeBase64Image(uri!),
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => const Icon(Icons.refresh_rounded,
                      size: 20, color: Colors.grey),
                ),
        ),
      ),
    );
  }

  /// 从 data URI / 裸 base64 取出图片字节；网络 URL 返回空（此时不渲染图片）
  static Uint8List _decodeBase64Image(String src) {
    final comma = src.indexOf(',');
    final payload = comma >= 0 && src.startsWith('data:') ? src.substring(comma + 1) : src;
    try {
      return base64Decode(payload);
    } catch (_) {
      return Uint8List(0);
    }
  }
}
