import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'auth/login_page.dart';
import 'core/http_client.dart';
import 'core/local_storage.dart';
import 'home/main_screen.dart';

const Color _yibinBlue = Color.fromRGBO(25, 25, 153, 1);

/// 主题模式通知器，供设置页监听
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.system);

/// 自定义页面切换动画：右滑 + 淡入
class _SlideTransition extends PageTransitionsBuilder {
  const _SlideTransition();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.3, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      )),
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }
}

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

class _SmartCampusAppState extends State<SmartCampusApp> {
  late ThemeMode _themeMode;
  SharedHttpClient? _client;

  @override
  void initState() {
    super.initState();
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
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _SlideTransition(),
          TargetPlatform.iOS: _SlideTransition(),
          TargetPlatform.windows: _SlideTransition(),
          TargetPlatform.linux: _SlideTransition(),
          TargetPlatform.macOS: _SlideTransition(),
        },
      ),

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
        unselectedItemColor: Colors.grey.shade500,
        type: BottomNavigationBarType.fixed,
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
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
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
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => MainScreen(
            client: client,
            userId: savedUser,
          ),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                  CurvedAnimation(
                      parent: animation, curve: Curves.easeOutCubic),
                ),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const LoginPage(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
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
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  return Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1 + _pulse.value * 0.1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      Icons.school_rounded,
                      size: 44,
                      color: Colors.white.withValues(alpha: 0.7 + _pulse.value * 0.3),
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
                '验证 Cookie 中…',
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
