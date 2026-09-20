import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart' show CupertinoThemeData, CupertinoTextThemeData;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

// ⚠️ 启动分流（CAS 重登 / 游客 / 新生 / 登录页跳转）已迁至
// splash/startup_flow.dart，由 welcome/welcome_gate.dart 在欢迎首屏
// 展示期间后台执行，故此处不再需要 auth / home / simple_page 等导入。
import 'core/crash_log.dart';
import 'core/glass_style.dart';
import 'core/http_client.dart';
import 'core/input_adaptation.dart';
import 'core/liquid_background.dart';
import 'core/local_storage.dart';
import 'core/theme_utils.dart';
import 'welcome/welcome_gate.dart';

/// 界面「墨色」通知器（2026-09-20 白底重构：不再是可自定义的「主题色」）。
///
/// 语义变更：原为用户可选的主题强调色，现改为**中性墨色**——浅色模式取近黑
/// [kInkLight]、深色模式取近白 [kInkDark]，由 [_SmartCampusAppState] 按当前
/// 明暗模式自动同步（见 `_syncInkColor`）。全项目约 60 个文件仍读此值，
/// 保留名称与 API 以免大范围改动；颜色表达改由模块图标自身承载
/// （`home/app_data.dart` 的 `AppEntry.color`）。
final ValueNotifier<Color> accentColorNotifier = ValueNotifier(kInkLight);

/// 主题模式通知器，供设置页监听
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.system);

/// 自定义背景图片路径通知器（null 表示使用默认纯色背景）
final ValueNotifier<String?> backgroundNotifier = ValueNotifier(null);

void main() {
  // 全局异常捕获（含未捕获异步错误）→ 写入本地 crash.log，
  // 便于排查桌面端闪退（Windows: %APPDATA%\smartcampus\logs\crash.log）
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await CrashLog.init();

    // ⚠️ 2026-08-20：LiquidGlassWidgets.initialize() 内部用
    // FragmentProgram.fromAsset 预编译多个玻璃 shader——在 Windows
    // Impeller(D3D12) 上首次编译耗时可达数分钟。若在 runApp 前 await，
    // 首帧永远不会渲染 → 窗口白屏数分钟（v1.2.4 修复窗口显示后暴露）。
    // 改为 runApp 后异步预热：首帧立即渲染欢迎首屏；玻璃组件自带
    // fallback 渲染，shader 就绪后自动切换到完整玻璃效果。
    final Future<void> glassInit = LiquidGlassWidgets.initialize();

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

    // 注：2026-09-20 起不再读取历史 `accent_color`（主题色已废弃，
    // 界面强调色改为随明暗模式自动切换的中性墨色）。

    runApp(LiquidGlassWidgets.wrap(
      child: SmartCampusApp(
        initialThemeMode: initialMode,
      ),
      // 0.29.1 起 MaterialApp 用户必须提供：修复深色系统 + 浅色应用时玻璃阴影丢失
      brightnessResolver: Theme.maybeBrightnessOf,
      // ⚠️ 2026-09-20 材质定案：界面玻璃整体置为「实色」（无模糊/折射/高光），
      // 液态玻璃只保留在导航栏——底部 GlassTabBar.bottom 与宽屏侧栏均自带
      // 显式液态参数，优先级高于本主题，故不受影响。
      // 参数与理由见 core/glass_style.dart。
      theme: kAppGlassTheme,
    ));

    // ⚠️ 首帧渲染完成后再预热 shader（addPostFrameCallback 保证 runApp
    // 的首帧已提交渲染，此后预热不再阻塞任何帧）。fire-and-forget：
    // 预热失败/超时只影响玻璃观感（组件自带 fallback 渲染），不影响功能。
    // 15s 超时兜底：Windows Impeller(D3D12) 上 FragmentProgram 首次编译
    // 可能极慢甚至挂起，超时后放弃预热，组件以 fallback 玻璃继续工作。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      glassInit
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => CrashLog.write(
                'LiquidGlassWidgets.initialize TIMEOUT(15s), fallback glass'),
          )
          .catchError((Object e) {
        CrashLog.write('LiquidGlassWidgets.initialize FAILED: $e');
      });
    });
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
    // 首帧后同步墨色（不能同步调用：会触发 setState during build）
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncInkColor());
  }

  void _onAccentColorChanged() => setState(() {});

  /// 当前生效的明暗模式（跟随系统时取平台亮度）
  Brightness _effectiveBrightness() {
    if (_themeMode == ThemeMode.dark) return Brightness.dark;
    if (_themeMode == ThemeMode.light) return Brightness.light;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness;
  }

  /// 依据明暗模式同步界面墨色：浅色近黑 / 深色近白。
  /// 全部读取 `accentColorNotifier.value` 的页面/组件随之自动切换到中性色。
  void _syncInkColor() {
    final target =
        _effectiveBrightness() == Brightness.dark ? kInkDark : kInkLight;
    if (accentColorNotifier.value.toARGB32() != target.toARGB32()) {
      accentColorNotifier.value = target; // 触发 _onAccentColorChanged → setState
    }
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    _syncInkColor();
  }

  ThemeMode get themeMode => _themeMode;
  SharedHttpClient? get client => _client;

  void setClient(SharedHttpClient c) => _client = c;

  Future<void> setThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    themeModeNotifier.value = mode;
    _syncInkColor(); // 明暗切换同时切换墨色（浅色近黑 / 深色近白）
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
      // 中文本地化：CupertinoDatePicker 等组件显示中文（月份「N月」等）
      locale: const Locale('zh'),
      supportedLocales: const [Locale('zh'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
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
      // 启动入口：每次启动先展示欢迎首屏（WelcomeGate → 向上拉出/点开始使用
      // 就地进入；会话分流在欢迎页展示期间后台完成，见 splash/startup_flow.dart）
      home: const WelcomeGate(),
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
      // 白底重构：浅色模式墨色近黑 → onPrimary 用白；深色模式墨色近白 → 用黑
      onPrimary: isDark ? const Color(0xFF111114) : Colors.white,
      surface: cardColor,
      onSurface: isDark ? Colors.white : const Color(0xFF1A1A2E),
    );

    // ⚠️ Windows 字体统一：不设置时系统默认 Segoe UI 与中文雅黑 fallback
    // 混排，中英文字重渲染不一致（"有粗有细"）；统一微软雅黑后一致。
    final isWindows = !kIsWeb && Platform.isWindows;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      // Windows 统一微软雅黑（常量见 theme_utils.dart）；移动端不指定（跟随系统字体）
      fontFamily: isWindows ? kWindowsFontFamily : null,
      fontFamilyFallback: isWindows
          ? kWindowsFontFallback
          : const ['PingFang SC', 'Noto Sans SC'],

      // Cupertino 组件（GlassScaffold 内部基于 CupertinoPageScaffold 等）
      // 默认用平台字体（Windows = Segoe UI），不吃 Material fontFamily——
      // 显式覆盖为与 Material 一致的字体，杜绝混排粗细不一。
      // ⚠️ 只设 textStyle 不够：Cupertino 各组件 style（按钮/导航栏/
      // 分段/选择器）各自回退系统字体——逐个显式指定 fontFamily
      // （其余字段保持 null，自动继承默认配色字号）。
      cupertinoOverrideTheme: CupertinoThemeData(
        // ⚠️ 必须显式传 brightness：不传时 CupertinoTheme.brightnessOf 回退
        // MediaQuery.platformBrightnessOf（系统亮度），App 强制深色但系统浅色时
        // Cupertino 动态色（label 等）解析为黑色 → GlassListTile 等库组件
        // title 黑字看不清（2026-08-14 修复）。
        brightness: brightness,
        primaryColor: accent,
        textTheme: CupertinoTextThemeData(
          // ⚠️ 参数名必须对齐 SDK CupertinoTextThemeData 实际定义：
          // 无 primaryTextStyle / navigationActionTextStyle / segmentedControlTextStyle
          // （编译错误，2026-08-09 修复）；navActionTextStyle 才是按钮/导航栏动作样式。
          textStyle:
              TextStyle(fontFamily: isWindows ? kWindowsFontFamily : null),
          actionTextStyle:
              TextStyle(fontFamily: isWindows ? kWindowsFontFamily : null),
          actionSmallTextStyle:
              TextStyle(fontFamily: isWindows ? kWindowsFontFamily : null),
          tabLabelTextStyle:
              TextStyle(fontFamily: isWindows ? kWindowsFontFamily : null),
          navTitleTextStyle:
              TextStyle(fontFamily: isWindows ? kWindowsFontFamily : null),
          navLargeTitleTextStyle:
              TextStyle(fontFamily: isWindows ? kWindowsFontFamily : null),
          navActionTextStyle:
              TextStyle(fontFamily: isWindows ? kWindowsFontFamily : null),
          pickerTextStyle:
              TextStyle(fontFamily: isWindows ? kWindowsFontFamily : null),
          dateTimePickerTextStyle:
              TextStyle(fontFamily: isWindows ? kWindowsFontFamily : null),
        ),
      ),

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
          fontFamily: isWindows ? kWindowsFontFamily : null,
        ),
      ),

      // 卡片：实色（2026-09-20 取消界面毛玻璃）——白 / 深色近黑 + 极淡描边；
      // 不再使用半透明填充与白色高光描边。
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.07),
          ),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          // 白底重构：主按钮为墨色实心（浅色=近黑+白字 / 深色=近白+黑字）
          backgroundColor: accent,
          foregroundColor:
              isDark ? const Color(0xFF111114) : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        // 实色输入框底色（iOS 分组灰 / 深色 secondarySystemGroupedBackground），
        // 2026-09-20 取消半透明玻璃填充
        fillColor:
            isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : const Color(0xFFE5E5EA),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : const Color(0xFFE5E5EA),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          // 聚焦边框用墨色（去主题色：浅色近黑 / 深色近白）
          borderSide: BorderSide(
            color: accent.withValues(alpha: isDark ? 0.5 : 0.55),
            width: 1.5,
          ),
        ),
        // 表单校验错误文字统一用深橙（应用界面文字不用红色）
        errorStyle: TextStyle(
          color: const Color(0xFFC2410C),
          fontSize: 12,
          fontFamily: isWindows ? kWindowsFontFamily : null,
        ),
        labelStyle: TextStyle(
          color: isDark ? Colors.white70 : const Color(0xFF6E6E80),
          fontFamily: isWindows ? kWindowsFontFamily : null,
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        elevation: 0,
        backgroundColor: Colors.transparent,
        // 选中色 = 墨色（浅色近黑 / 深色近白），未选中为中性灰
        selectedItemColor: accent,
        unselectedItemColor:
            isDark ? const Color(0xFF6E6E80) : Colors.grey.shade500,
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
          fontFamily: isWindows ? kWindowsFontFamily : null,
        ),
        subtitleTextStyle: TextStyle(
          fontSize: 12,
          color: isDark ? const Color(0xFF9E9EB0) : Colors.grey.shade500,
          fontFamily: isWindows ? kWindowsFontFamily : null,
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

