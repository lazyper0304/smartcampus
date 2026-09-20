import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// ============================================================================
/// 界面材质统一配置（2026-09-20 白底重构）
///
/// 设计定案：
/// - **界面内容**（卡片 / 弹窗 / 列表分组 / 筛选按钮 / 分段控件 / 宫格）→
///   一律「实色」：不模糊、不折射、无高光，白色（深色模式近黑）平面卡面；
/// - **液态玻璃只保留在导航栏**：底部 [GlassTabBar.bottom] 与宽屏侧边
///   导航栏，参数在各自组件处显式传入（导航栏自带 settings，不依赖本文件）。
///
/// 实现原理（liquid_glass_widgets 1.2.3 设置解析优先级）：
/// `effectiveSettings = widget.settings ?? GlassTheme.settingsFor(context)`，
/// 即**组件显式 settings 优先，其次才是全局 GlassTheme**。因此：
/// 1. 把全局 `GlassTheme` 设为实色 → 所有未显式传参的库存玻璃组件自动变实色；
/// 2. 导航栏已显式传入液态 settings → 不受影响，继续液态玻璃。
/// ============================================================================

// ---------------------------------------------------------------------------
// 全局 GlassTheme：实色（浅色白 / 深色近黑）
// ---------------------------------------------------------------------------

/// 实色玻璃参数（浅色）：不透明白 + 关闭模糊/折射/高光/色散
///
/// ⚠️ [GlassThemeSettings] 只接受库公开的部分字段（无 `whitenStrength` /
/// `shadowElevation` 等，那些是 [LiquidGlassSettings] 独有字段）。
const GlassThemeSettings kFlatGlassLight = GlassThemeSettings(
  // 90% 白：完全平面，仅保留一丝背景透出（避免生硬纯白）
  glassColor: Color(0xE6FFFFFF),
  thickness: 0, // 无体积厚度 → 不产生折射位移
  blur: 0, // 无背景模糊 → 无毛玻璃
  chromaticAberration: 0, // 无色散
  lightIntensity: 0, // 无镜面高光
  ambientStrength: 0,
  fresnelStrength: 0, // 无边缘亮环
  refractiveIndex: 1.0, // 折射率 1.0 = 不折射
  saturation: 1.0,
  specularSharpness: GlassSpecularSharpness.soft,
  edgeAbsorption: 0,
);

/// 实色玻璃参数（深色）：不透明近黑
const GlassThemeSettings kFlatGlassDark = GlassThemeSettings(
  glassColor: Color(0xE61C1C1E),
  thickness: 0,
  blur: 0,
  chromaticAberration: 0,
  lightIntensity: 0,
  ambientStrength: 0,
  fresnelStrength: 0,
  refractiveIndex: 1.0,
  saturation: 1.0,
  specularSharpness: GlassSpecularSharpness.soft,
  edgeAbsorption: 0,
);

/// 应用级玻璃主题：全局实色（导航栏各自显式传液态参数，不受此影响）
const GlassThemeData kAppGlassTheme = GlassThemeData(
  light: GlassThemeVariant(
    settings: kFlatGlassLight,
    quality: GlassQuality.standard,
    glowColors: GlassGlowColors(
      glowBlurRadius: 0,
      glowSpreadRadius: 0,
      glowOpacity: 0,
    ),
  ),
  dark: GlassThemeVariant(
    settings: kFlatGlassDark,
    quality: GlassQuality.standard,
    glowColors: GlassGlowColors(
      glowBlurRadius: 0,
      glowSpreadRadius: 0,
      glowOpacity: 0,
    ),
  ),
);

/// 页面外壳层参数（[GlassScaffold] / [GlassPage] 的 `settings`）：
/// 与全局实色一致——页面层不再模糊背景，界面整体呈白色平面。
const LiquidGlassSettings kFlatPageSettings = LiquidGlassSettings(
  glassColor: Color(0xE6FFFFFF),
  thickness: 0,
  blur: 0,
  chromaticAberration: 0,
  lightIntensity: 0,
  ambientStrength: 0,
  fresnelStrength: 0,
  refractiveIndex: 1.0,
  saturation: 1.0,
  specularSharpness: GlassSpecularSharpness.soft,
  standardOpacityMultiplier: 1.0,
  shadowElevation: 0,
);

/// 页面外壳层参数（深色）
const LiquidGlassSettings kFlatPageSettingsDark = LiquidGlassSettings(
  glassColor: Color(0xE61C1C1E),
  thickness: 0,
  blur: 0,
  chromaticAberration: 0,
  lightIntensity: 0,
  ambientStrength: 0,
  fresnelStrength: 0,
  refractiveIndex: 1.0,
  saturation: 1.0,
  specularSharpness: GlassSpecularSharpness.soft,
  standardOpacityMultiplier: 1.0,
  shadowElevation: 0,
);

// ---------------------------------------------------------------------------
// 实色卡面装饰（自绘组件：卡片 / 分组列表 / 弹窗 / 宫格方块统一使用）
// ---------------------------------------------------------------------------

/// 实色卡面填充色（浅色纯白 / 深色 iOS secondarySystemGroupedBackground）
Color solidSurface(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1C1C1E)
        : Colors.white;

/// 实色卡面描边色：白色卡面在白底上需要一条极淡的分隔线区分边界
Color solidHairline(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.07);

/// 实色卡面投影：白底上提供轻微层次（深色模式不用投影）
List<BoxShadow> solidShadow(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const []
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ];
