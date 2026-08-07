import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'auth/auth_service.dart';
import 'auth/login_page.dart';
import 'core/guest_mode.dart';
import 'core/crash_log.dart';
import 'core/http_client.dart';
import 'core/input_adaptation.dart';
import 'core/liquid_background.dart';
import 'core/local_storage.dart';
import 'core/navigation.dart';
import 'core/simple_page.dart';
import 'home/main_screen.dart';
import 'splash/fetch_info_page.dart';
import 'xuegong/student_info_manager.dart';

const Color _yibinBlue = Color.fromRGBO(25, 25, 153, 1);

/// 主题模式通知器，供设置页监听
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.system);

/// 自定义背景图片路径通知器（null 表示使用默认纯色背景）
final ValueNotifier<String?> backgroundNotifier = ValueNotifier(null);

/// 主题强调色通知器（默认宜院蓝）
final ValueNotifier<Color> accentColorNotifier = ValueNotifier(_yibinBlue);

/// 将 Color 序列化为十六进制字符串
String colorToHex(Color c) =>
    '#${c.red.toRadixString(16).padLeft(2, '0')}'
    '${c.green.toRadixString(16).padLeft(2, '0')}'
    '${c.blue.toRadixString(16).padLeft(2, '0')}';

/// 从十六进制字符串解析 Color，失败返回默认值
Color hexToColor(String hex, [Color fallback = _yibinBlue]) {
  try {
    hex = hex.replaceFirst('#', '');
    if (hex.length != 6) return fallback;
    final r = int.parse(hex.substring(0, 2), radix: 16);
    final g = int.parse(hex.substring(2, 4), radix: 16);
    final b = int.parse(hex.substring(4, 6), radix: 16);
    return Color.fromRGBO(r, g, b, 1);
  } catch (_) {
    return fallback;
  }
}

void main() {
  // 全局异常捕获（含未捕获异步错误）→ 写入本地 crash.log，
  // 便于排查桌面端闪退（Windows: %APPDATA%\smartcampus\logs\crash.log）
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await CrashLog.init();
    await LiquidGlassWidgets.initialize();

    // 加载保存的主题模式
    final saved = await LocalStorage.getString('theme_mode');
    final initialMode = ThemeMode.values.firstWhere(
      (e) => e.name == saved,
      orElse: () => ThemeMode.system,
    );

    // 加载保存的背景图片路径
    final savedBg = await LocalStorage.getString('background_image');
    if (savedBg != null && savedBg.isNotEmpty) {
      backgroundNotifier.value = savedBg;
    }

    // 加载保存的主题颜色
    final savedColor = await LocalStorage.getString('accent_color');
    if (savedColor != null && savedColor.isNotEmpty) {
      accentColorNotifier.value = hexToColor(savedColor);
    }

    runApp(LiquidGlassWidgets.wrap(
      child: SmartCampusApp(
        initialThemeMode: initialMode,
      ),
      // 0.29.1 起 MaterialApp 用户必须提供：修复深色系统 + 浅色应用时玻璃阴影丢失
      brightnessResolver: Theme.maybeBrightnessOf,
      theme: GlassThemeData(
        // ⚠️ 质量必须用 standard：premium 在 ListView/CustomScrollView 内
        // 于 Impeller 上可能渲染错误（整页白屏）。standard 是官方推荐默认，
        // 滚动内容安全；导航栏/底部栏由 GlassScaffold 的 GlassIsolationScope
        // 自动提升为 premium，无需担心观感下降。
        light: GlassThemeVariant(
          settings: GlassThemeSettings(thickness: 32, blur: 14),
          quality: GlassQuality.standard,
          glowColors: GlassGlowColors(
            primary: Colors.white,
            glowBlurRadius: 32,
            glowSpreadRadius: 0.8,
            glowOpacity: 0.6,
          ),
        ),
        dark: GlassThemeVariant(
          settings: GlassThemeSettings(thickness: 32, blur: 14),
          quality: GlassQuality.standard,
          glowColors: GlassGlowColors(
            primary: Colors.white,
            glowBlurRadius: 24,
            glowSpreadRadius: 0.6,
            glowOpacity: 0.4,
          ),
        ),
      ),
    ));
  }, (error, stack) {
    CrashLog.write('UNCAUGHT_ZONE_ERROR: $error\n$stack');
  });
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

  /// 全局 Navigator 句柄：供 AppShortcuts（Esc 返回）等位于 Navigator
  /// 之上的层触达路由栈。
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _themeMode = widget.initialThemeMode;
    _client = widget.initialClient;
    accentColorNotifier.addListener(_onAccentColorChanged);
  }

  void _onAccentColorChanged() => setState(() {});

  ThemeMode get themeMode => _themeMode;
  SharedHttpClient? get client => _client;

  void setClient(SharedHttpClient c) => _client = c;

  Future<void> setThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    themeModeNotifier.value = mode;
    await LocalStorage.setString('theme_mode', mode.name);
  }

  /// 设置自定义背景图片，null 为恢复默认
  Future<void> setBackground(String? path) async {
    backgroundNotifier.value = path;
    if (path != null) {
      await LocalStorage.setString('background_image', path);
    } else {
      await LocalStorage.remove('background_image');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 进后台：仅保存 Cookie，不强制关闭 App，保证进程保留在后台、可随时返回。
    // Cookie 落盘由此处 + 每次请求后 3s 防抖（_scheduleSave）共同保证。
    if (state == AppLifecycleState.paused) {
      _saveCookiesOnBackground();
    } else if (state == AppLifecycleState.detached) {
      // 进程即将被销毁时的兜底保存（不阻塞，失败忽略）
      _client?.saveCookies().catchError((_) {});
    }
  }

  /// 进后台时保存 Cookie（保留 App 在后台，不再调用 SystemNavigator.pop）
  Future<void> _saveCookiesOnBackground() async {
    await _client?.saveCookies();
  }

  @override
  void dispose() {
    accentColorNotifier.removeListener(_onAccentColorChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '宜院宾果',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: _themeMode,
      builder: (context, child) {
        // ⚠️ 全局输入适配：Esc 返回 + 动态组件密度（触控宽松/桌面紧凑）。
        // AppShortcuts 位于 Navigator 之上，Esc 经 navigatorKey 触达路由栈。
        return AppShortcuts(
          onEscape: () => _navigatorKey.currentState?.maybePop(),
          child: ValueListenableBuilder<Color>(
            valueListenable: accentColorNotifier,
            builder: (context, _, __) {
            final brightness = _themeMode == ThemeMode.dark
                ? Brightness.dark
                : _themeMode == ThemeMode.light
                    ? Brightness.light
                    : MediaQuery.platformBrightnessOf(context);
            // ⚠️ 自定义背景提升到全局：外观设置选择的图片应用到所有页面
            //（主界面 + 全部二级页），默认仍为液态玻璃背景（渐变+动态光斑）。
            return ValueListenableBuilder<String?>(
              valueListenable: backgroundNotifier,
              builder: (context, bgPath, child) {
                final bgOk = bgPath != null && bgPath.isNotEmpty;
                final isDark = brightness == Brightness.dark;
                final bg = bgOk
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            File(bgPath),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                // 全局垫底层（isGlobal）：被页面层覆盖时自动暂停气泡省电
                                const LiquidBackground(isGlobal: true),
                          ),
                          // 半透明遮罩确保内容可读性
                          Container(
                            color: (isDark
                                    ? const Color(0xFF1A1A2E)
                                    : Colors.white)
                                .withValues(alpha: 0.5),
                          ),
                        ],
                      )
                    : const LiquidBackground(isGlobal: true);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    bg,
                    child!,
                  ],
                );
              },
              child: Builder(
                builder: (ctx) {
                  // 多输入适配：组件密度随屏宽切换（触控 comfortable 宽松 /
                  // 桌面 compact 紧凑），覆盖全部 Material 内置组件
                  final width = MediaQuery.of(ctx).size.width;
                  return Theme(
                    data: _buildTheme(brightness)
                        .copyWith(visualDensity: adaptiveVisualDensity(width)),
                    child: child!,
                  );
                },
              ),
            );
          },
        )
        );
      },
      home: const SplashPage(),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final accent = accentColorNotifier.value;
    final isDark = brightness == Brightness.dark;
    // 卡片表面色（iOS secondarySystemGroupedBackground）
    final cardColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      primary: accent,
      onPrimary: Colors.white,
      surface: cardColor,
      onSurface: isDark ? Colors.white : const Color(0xFF1A1A2E),
    );

    // ⚠️ Windows 字体统一：不设置时系统默认 Segoe UI 与中文雅黑 fallback
    // 混排，中英文字重渲染不一致（"有粗有细"）；统一微软雅黑后一致。
    final isWindows = !kIsWeb && Platform.isWindows;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      // Windows 统一微软雅黑；移动端不指定（跟随系统字体）
      fontFamily: isWindows ? 'Microsoft YaHei' : null,
      fontFamilyFallback: isWindows
          ? const ['Microsoft YaHei UI', 'SimHei']
          : const ['PingFang SC', 'Noto Sans SC'],

      // Scaffold 背景全透明：所有页面（含二级页）直接透出
      // builder 层 LiquidBackground 的主界面同款背景
      scaffoldBackgroundColor: Colors.transparent,

      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
          letterSpacing: 0.3,
        ),
      ),

      // iOS 卡片：静态玻璃（与主界面 contentCardGlass 同款参数——
      // 半透明白/深灰透出 LiquidBackground + 白色高光描边，无 BackdropFilter
      // 滚动稳定）；所有二级页面 Material Card 统一玻璃化（自带 color 的
      // 个别 Card 仍会覆盖，可单独处理）
      cardTheme: CardThemeData(
        color: isDark
            ? const Color(0xFF1C1C1E).withValues(alpha: 0.48)
            : Colors.white.withValues(alpha: 0.38),
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.45),
          ),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: isDark ? const Color(0xFF3D3DF0) : accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        // 静态玻璃填充（与卡片同款：半透明白/深灰透出背景，无 BackdropFilter）
        fillColor: isDark
            ? const Color(0xFF1C1C1E).withValues(alpha: 0.48)
            : Colors.white.withValues(alpha: 0.38),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.45),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.white.withValues(alpha: 0.35),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          // 聚焦边框用中性白描边（不加主题色）：仅加亮加粗提供聚焦反馈，
          // 颜色与主题色解耦，避免输入框聚焦时显示紫色等强调色边框。
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.65),
            width: 1.5,
          ),
        ),
        // 表单校验错误文字统一用深橙（应用界面文字不用红色）
        errorStyle: const TextStyle(color: Color(0xFFC2410C), fontSize: 12),
        labelStyle: TextStyle(color: isDark ? Colors.white70 : accent.withValues(alpha: 0.6)),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        elevation: 0,
        backgroundColor: Colors.transparent,
        selectedItemColor: isDark ? const Color(0xFF5C5CFF) : accent,
        unselectedItemColor: isDark ? const Color(0xFF6E6E80) : Colors.grey.shade500,
        type: BottomNavigationBarType.fixed,
      ),

      dividerTheme: DividerThemeData(
        color: isDark ? const Color(0xFF3A3A4E) : const Color(0xFFE5E5EA),
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
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
    await GuestMode.load();

    // 游客模式：跳过会话校验，直接进入首页（仅可用免登录功能）
    if (GuestMode.active) {
      if (!mounted) return;
      replacePage(context, MainScreen(client: client, userId: ''));
      return;
    }

    // ⚠️ 每次进入应用都用本地保存的账号密码走**真实 CAS 登录**（全新 cookie），
    // 不再复用可能已过期的本地 cookie（服务端 TTL 过期后本地是"死 cookie"，
    // 注入 WebView 只会触发 CAS 刷新回环 → 学科竞赛等模块获取失败）。
    // 登录成功后 Cookie 已全部刷新并落盘，会话永远新鲜，无需手动重新登录。
    final autoAuth = AuthService(sharedClient: client);
    if (await autoAuth.autoRelogin()) {
      if (!mounted) return;
      final savedUser = await LocalStorage.getString('saved_username') ?? '';

      // 首次进入需先获取到个人信息（无缓存时走 FetchInfoPage 阻塞获取），
      // 后续有缓存直接进主界面
      final cached = await StudentInfoManager.getCached();
      if (!mounted) return;
      if (cached == null) {
        replacePage(context, FetchInfoPage(client: client));
        return;
      }

      if (!mounted) return;
      replacePage(context, MainScreen(client: client, userId: savedUser));
      return;
    }

    // 无本地凭据（首次使用 / 已退出登录 / 自动重登失败）→ 登录页；
    // 登录成功后凭据会保存，下次启动即可自动重登。
    if (!mounted) return;
    replacePage(context, const LoginPage());
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    // 主界面同款液态玻璃背景 + 统一状态栏（SimplePage 基座），
    // 登录后过渡界面与二级页观感一致
    return SimplePage(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
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
                      color: onSurface.withValues(alpha: 0.08 + pulse * 0.06),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      Icons.school_rounded,
                      size: 44,
                      color: onSurface.withValues(alpha: 0.6 + pulse * 0.3),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                '宜院宾果',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: onSurface,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '验证 Cookie 中…',
                style: TextStyle(
                  fontSize: 14,
                  color: onSurface.withValues(alpha: 0.5),
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
