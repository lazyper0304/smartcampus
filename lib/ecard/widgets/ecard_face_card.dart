import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../ecard_assets.dart';
import 'ecard_face_glow.dart';

/// 钱包页卡面；优先 [faceFilePath]，否则 [faceAssetPath]；光晕从同图采样。
class EcardFaceCard extends StatefulWidget {
  const EcardFaceCard({
    super.key,
    this.faceId = 0,
    this.faceImageMd5 = '',
    this.faceAssetPath = EcardAssets.defaultCardFace,
    this.faceFilePath,
  });

  /// 当前卡面 id（0=内置），用于在路径未变时仍能识别切换。
  final int faceId;
  final String faceImageMd5;
  final String faceAssetPath;
  final String? faceFilePath;

  @override
  State<EcardFaceCard> createState() => _EcardFaceCardState();
}

class _EcardFaceCardState extends State<EcardFaceCard> {
  EcardFaceGlowPalette? _palette;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPalette());
  }

  @override
  void didUpdateWidget(covariant EcardFaceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameFaceSource(oldWidget)) {
      final oldPath = oldWidget.faceFilePath;
      if (oldPath != null && oldPath.isNotEmpty) {
        EcardFaceGlowPalette.evictFile(oldPath, imageMd5: oldWidget.faceImageMd5);
      }
      setState(() => _palette = null);
      unawaited(_loadPalette());
    }
  }

  bool _sameFaceSource(EcardFaceCard other) {
    return other.faceId == widget.faceId &&
        other.faceImageMd5 == widget.faceImageMd5 &&
        other.faceAssetPath == widget.faceAssetPath &&
        other.faceFilePath == widget.faceFilePath;
  }

  bool _useLocalFile() {
    final file = widget.faceFilePath;
    return file != null && file.isNotEmpty && File(file).existsSync();
  }

  Future<void> _loadPalette() async {
    final faceId = widget.faceId;
    final file = widget.faceFilePath;
    final asset = widget.faceAssetPath;
    final useFile = _useLocalFile();
    final md5 = widget.faceImageMd5;
    final palette = useFile
        ? await EcardFaceGlowPalette.loadFile(file!, imageMd5: md5)
        : await EcardFaceGlowPalette.load(asset);
    if (!mounted) return;
    if (widget.faceId != faceId ||
        widget.faceImageMd5 != md5 ||
        widget.faceFilePath != file ||
        widget.faceAssetPath != asset) {
      return;
    }
    if (_useLocalFile() != useFile) return;
    setState(() => _palette = palette);
  }

  Widget _faceImage() {
    if (_useLocalFile()) {
      final path = widget.faceFilePath!;
      return Image.file(
        File(path),
        key: ValueKey('ecard-face-file-$path'),
        fit: BoxFit.cover,
        alignment: Alignment.center,
      );
    }
    return Image.asset(
      widget.faceAssetPath,
      key: ValueKey('ecard-face-asset-${widget.faceAssetPath}'),
      fit: BoxFit.cover,
      alignment: Alignment.center,
    );
  }

  @override
  Widget build(BuildContext context) {
    const radius = 16.0;
    const aspectRatio = 1.586;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = _palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 22),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            _CardNeutralShadowLayer(radius: radius, isDark: isDark),
            if (palette != null)
              _CardEdgeGlowLayer(
                palette: palette,
                radius: radius,
                isDark: isDark,
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                boxShadow: _cardContactShadow(isDark),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: _faceImage(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<BoxShadow> _cardContactShadow(bool isDark) {
  if (isDark) {
    return [
      BoxShadow(
        color: const Color(0xFF3A3A3C).withValues(alpha: 0.38),
        blurRadius: 22,
        spreadRadius: -3,
        offset: const Offset(0, 10),
      ),
      BoxShadow(
        color: const Color(0xFF000000).withValues(alpha: 0.26),
        blurRadius: 7,
        spreadRadius: 0,
        offset: const Offset(0, 3),
      ),
    ];
  }
  return [
    BoxShadow(
      color: const Color(0xFF3C3C43).withValues(alpha: 0.11),
      blurRadius: 16,
      spreadRadius: -3,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: const Color(0xFF3C3C43).withValues(alpha: 0.08),
      blurRadius: 5,
      spreadRadius: -1,
      offset: const Offset(0, 2),
    ),
  ];
}

/// 少量中性灰落影（非硬编码品牌色，仅 iOS 系中性灰）
class _CardNeutralShadowLayer extends StatelessWidget {
  const _CardNeutralShadowLayer({required this.radius, required this.isDark});

  final double radius;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    // 暗色页纯黑底：用深灰落影，避免中灰高亮像底灯
    final fill = isDark ? const Color(0xFF2C2C2E) : const Color(0xFF6B7280);
    final plateOpacity = isDark ? 0.34 : 0.17;

    return Positioned.fill(
      child: Transform.translate(
        offset: Offset(0, isDark ? 9 : 8),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isDark ? 8 : 8),
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: isDark ? 22 : 20, sigmaY: isDark ? 20 : 17),
            child: Opacity(
              opacity: plateOpacity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  color: fill,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardEdgeGlowLayer extends StatelessWidget {
  const _CardEdgeGlowLayer({
    required this.palette,
    required this.radius,
    required this.isDark,
  });

  final EcardFaceGlowPalette palette;
  final double radius;
  final bool isDark;

  Color _g(Color c, double alpha) => EcardFaceGlowPalette.toGlow(c, alpha: alpha, isDark: isDark);

  @override
  Widget build(BuildContext context) {
    final sideA = isDark ? 0.22 : 0.24;
    final vertA = isDark ? 0.18 : 0.2;

    final topC = _g(palette.top, vertA);
    final bottomC = _g(palette.bottom, sideA);
    final leftC = _g(palette.left, sideA);
    final rightC = _g(palette.right, sideA);

    // 底/顶：左右边色向中间底/顶边色平滑过渡（整带采样，无横向分段）
    final bottomGradient = [leftC, bottomC, rightC];
    final topGradient = [leftC, topC, rightC];

    return Positioned.fill(
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Transform.translate(
              offset: const Offset(0, -5),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 14, sigmaY: 10),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: topGradient,
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Transform.translate(
              offset: const Offset(0, 7),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 14),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius + 2),
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: bottomGradient,
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  gradient: RadialGradient(
                    center: const Alignment(-1.02, 0.5),
                    radius: 0.52,
                    colors: [leftC, leftC.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  gradient: RadialGradient(
                    center: const Alignment(1.02, 0.5),
                    radius: 0.52,
                    colors: [rightC, rightC.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
