import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cue/cue.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'auth/login_page.dart';
import 'core/http_client.dart';
import 'core/local_storage.dart';
import 'core/navigation.dart';
import 'home/main_screen.dart';
import 'xuegong/student_info_manager.dart';

const Color _yibinBlue = Color.fromRGBO(25, 25, 153, 1);

/// 主题模式通知器，供设置页监听
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize();

  // 加载保存的主题模式
  final saved = await LocalStorage.getString('theme_mode');
  final initialMode = ThemeMode.values.firstWhere(
    (e) => e.name == saved,
    orElse: () => ThemeMode.system,
  );

  runApp(LiquidGlassWidgets.wrap(
    child: SmartCampusApp(initialThemeMode: initialMode),
    theme: GlassThemeData(
      light: GlassThemeVariant(
        settings: GlassThemeSettings(thickness: 45, blur: 18),
        quality: GlassQuality.premium,
        glowColors: GlassGlowColors(
          primary: _yibinBlue,
          glowBlurRadius: 32,
          glowSpreadRadius: 0.8,
          glowOpacity: 1.0,
        ),
      ),
      dark: GlassThemeVariant(
        settings: GlassThemeSettings(thickness: 45, blur: 18),
        quality: GlassQuality.premium,
        glowColors: GlassGlowColors(
          primary: _yibinBlue,
          glowBlurRadius: 24,
          glowSpreadRadius: 0.6,
          glowOpacity: 1.0,
        ),
      ),
    ),
  ));
}

class SmartCampusApp extends StatefulWidget {
  final ThemeMode initialThemeMode;
  final SharedHttpClient? initialClient;

  const SmartCampusApp({
    super.key,
    this.initialThemeMode = ThemeMode.system,
    this.initialClient,
  });

  static _SmartCampusAppState? of(BuildContext context) {
    return context.findAncestorStateOfType<_SmartCampusAppState>();
  }

  @override
  State<SmartCampusApp> createState() => _SmartCampusAppState();
}

class _SmartCampusAppState extends State<SmartCampusApp>
    with WidgetsBindingObserver {
  late ThemeMode _themeMode;
  SharedHttpClient? _client;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _themeMode = widget.initialThemeMode;
    _client = widget.initialClient;
  }

  ThemeMode get themeMode => _themeMode;
  SharedHttpClient? get client => _client;

  void setClient(SharedHttpClient c) => _client = c;

  Future<void> setThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    themeModeNotifier.value = mode;
    await LocalStorage.setString('theme_mode', mode.name);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _saveAndExit();
    }
  }

  Future<void> _saveAndExit() async {
    await _client?.saveCookies();
    if (mounted) {
      await SystemNavigator.pop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '宜院宾果',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: _themeMode,
      home: const SplashPage(),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _yibinBlue,
      brightness: brightness,
      primary: _yibinBlue,
      onPrimary: Colors.white,
      surface: isDark ? const Color(0xFF121212) : const Color(0xFFF0F4FF),
      onSurface: isDark ? Colors.white : const Color(0xFF1A1A2E),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,


      scaffoldBackgroundColor: isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF0F4FF),

      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
          letterSpacing: 0.5,
        ),
      ),

      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
        elevation: 1,
        shadowColor: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: isDark ? const Color(0xFF3D3DF0) : _yibinBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF2A2A3E) : _yibinBlue.withValues(alpha: 0.04),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: (isDark ? Colors.white : _yibinBlue).withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: (isDark ? Colors.white : _yibinBlue).withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? const Color(0xFF5C5CFF) : _yibinBlue, width: 2),
        ),
        labelStyle: TextStyle(color: isDark ? Colors.white70 : _yibinBlue.withValues(alpha: 0.6)),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        elevation: 8,
        backgroundColor: colorScheme.surface,
        selectedItemColor: isDark ? const Color(0xFF5C5CFF) : _yibinBlue,
        unselectedItemColor: isDark ? const Color(0xFF6E6E80) : Colors.grey.shade500,
        type: BottomNavigationBarType.fixed,
      ),

      dividerTheme: DividerThemeData(
        color: isDark ? const Color(0xFF3A3A4E) : const Color(0xFFEEEEF4),
        space: 1,
        thickness: 1,
      ),

      listTileTheme: ListTileThemeData(
        titleTextStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
        subtitleTextStyle: TextStyle(
          fontSize: 12,
          color: isDark ? const Color(0xFF9E9EB0) : Colors.grey.shade500,
        ),
        iconColor: isDark ? const Color(0xFF9E9EB0) : Colors.grey.shade500,
      ),

      iconTheme: IconThemeData(
        color: isDark ? const Color(0xFF9E9EB0) : Colors.grey.shade500,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? const Color(0xFF2A2A3E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// 启动页：检查会话是否有效
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with TickerProviderStateMixin {
  late final CueController _animCtrl;
  String _statusText = '验证 Cookie 中…';

  void _updateStatus(String text) {
    if (mounted) setState(() => _statusText = text);
  }

  @override
  void initState() {
    super.initState();
    _animCtrl = CueController(vsync: this, motion: .smooth());
    _animCtrl.repeat(reverse: true);
    _checkSession();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkSession() async {
    // 至少显示 800ms 过渡动画
    await Future.delayed(const Duration(milliseconds: 800));
    final client = SharedHttpClient();
    await client.loadCookies();

    final isValid = await client.verifySession();

    if (!mounted) return;

    if (isValid) {
      final savedUser = await LocalStorage.getString('saved_username') ?? '';
      if (!mounted) return;

      // 首次进入才等待获取个人信息，后续使用缓存
      final cached = await StudentInfoManager.getCached();
      if (cached == null) {
        if (mounted) _updateStatus('正在获取个人信息…');
        await StudentInfoManager.fetchUntilSuccess(client);
      }

      if (!mounted) return;
      replacePage(context, MainScreen(client: client, userId: savedUser),
          acts: const [Act.fadeIn(), Act.scale(from: 0.92)]);
    } else {
      replacePage(context, const LoginPage(),
          acts: const [Act.fadeIn()]);
    }
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
                      Icons.school_rounded,
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
                _statusText,
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
