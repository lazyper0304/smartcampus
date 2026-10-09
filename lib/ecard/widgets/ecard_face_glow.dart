import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 卡面四边各 **5% 宽边框环**整带采样（不分段），用于卡片外侧着色。
class EcardFaceGlowPalette {
  const EcardFaceGlowPalette({
    required this.top,
    required this.bottom,
    required this.left,
    required this.right,
  });

  final Color top;
  final Color bottom;
  final Color left;
  final Color right;

  static const _edgeFraction = 0.05;
  /// 仅用边框带靠外的一半，减少采到靠内的点缀色（太阳、Logo 等）。
  static const _outerEdgePortion = 0.55;
  static const _cacheVersion = 'perimeter5_dominant_v5';

  static final Map<String, EcardFaceGlowPalette> _cache = {};

  static Future<EcardFaceGlowPalette?> load(String assetPath) async {
    final key = 'a:$assetPath|$_cacheVersion';
    final hit = _cache[key];
    if (hit != null) return hit;

    final sampled = await _sampleFromAsset(assetPath);
    if (sampled != null) _cache[key] = sampled;
    return sampled;
  }

  static Future<EcardFaceGlowPalette?> loadFile(String filePath, {String imageMd5 = ''}) async {
    final key = 'f:$filePath|$imageMd5|$_cacheVersion';
    final hit = _cache[key];
    if (hit != null) return hit;

    final sampled = await _sampleFromFile(filePath);
    if (sampled != null) _cache[key] = sampled;
    return sampled;
  }

  static void evictFile(String filePath, {String imageMd5 = ''}) {
    _cache.remove('f:$filePath|$imageMd5|$_cacheVersion');
  }

  static Future<EcardFaceGlowPalette?> _sampleFromFile(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      return await _sampleFromBytes(bytes);
    } catch (_) {
      return null;
    }
  }

  static void evict(String assetPath) => _cache.remove('$assetPath|$_cacheVersion');

  static Color toGlow(Color sampled, {required double alpha, bool isDark = false}) {
    final hsl = HSLColor.fromColor(sampled);
    // 主色采样偏淡（天空/海水）时饱和很低，需抬高才能看出色相。
    var sat = hsl.saturation;
    if (sat < 0.5) {
      sat = 0.42 + sat * 0.75;
    } else {
      sat *= isDark ? 1.12 : 1.14;
    }
    var light = isDark ? (hsl.lightness * 0.46 + 0.05) : (hsl.lightness * 0.48 + 0.05);
    light = light.clamp(isDark ? 0.2 : 0.22, isDark ? 0.46 : 0.5);
    return hsl
        .withLightness(light)
        .withSaturation(sat.clamp(0.0, 1.0))
        .toColor()
        .withValues(alpha: alpha);
  }

  static Future<EcardFaceGlowPalette?> _sampleFromAsset(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      return await _sampleFromBytes(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  static Future<EcardFaceGlowPalette?> _sampleFromBytes(List<int> rawBytes) async {
    try {
      final codec = await ui.instantiateImageCodec(
        rawBytes is Uint8List ? rawBytes : Uint8List.fromList(rawBytes),
        targetWidth: 260,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final w = image.width;
      final h = image.height;
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      if (bytes == null || w == 0 || h == 0) return null;

      Color px(int x, int y) {
        x = x.clamp(0, w - 1);
        y = y.clamp(0, h - 1);
        final i = (y * w + x) * 4;
        return Color.fromARGB(
          bytes.getUint8(i + 3),
          bytes.getUint8(i),
          bytes.getUint8(i + 1),
          bytes.getUint8(i + 2),
        );
      }

      final xBandFull = (w * _edgeFraction).ceil().clamp(1, w);
      final yBandFull = (h * _edgeFraction).ceil().clamp(1, h);
      final xBand = (xBandFull * _outerEdgePortion).ceil().clamp(1, xBandFull);
      final yBand = (yBandFull * _outerEdgePortion).ceil().clamp(1, yBandFull);

      Iterable<Color> rectPixels(int x0, int x1, int y0, int y1) sync* {
        for (var y = y0; y < y1; y++) {
          for (var x = x0; x < x1; x++) {
            yield px(x, y);
          }
        }
      }

      final topC = _pickFromPixels(rectPixels(0, w, 0, yBand));
      final bottomC = _pickFromPixels(rectPixels(0, w, h - yBand, h));
      final leftC = _pickFromPixels(rectPixels(0, xBand, 0, h));
      final rightC = _pickFromPixels(rectPixels(w - xBand, w, 0, h));
      if (topC == null || bottomC == null || leftC == null || rightC == null) return null;

      return EcardFaceGlowPalette(top: topC, bottom: bottomC, left: leftC, right: rightC);
    } catch (_) {
      return null;
    }
  }

  /// 主色 = 边缘带内占比最大的色相簇均值；淡色天空/海水不会被单个高饱和黄点带偏。
  static Color? _pickFromPixels(Iterable<Color> pixels) {
    final dominant = _dominantHueAverage(pixels);
    if (dominant != null) return dominant;

    final mean = _alphaWeightedAverage(pixels);
    if (mean != null) return mean;

    return _saturatedAverage(pixels);
  }

  static const _hueBinCount = 36;

  static Color? _dominantHueAverage(Iterable<Color> pixels) {
    final weights = List<double>.filled(_hueBinCount, 0);
    final sumR = List<double>.filled(_hueBinCount, 0);
    final sumG = List<double>.filled(_hueBinCount, 0);
    final sumB = List<double>.filled(_hueBinCount, 0);
    var chromaticWeight = 0.0;

    for (final c in pixels) {
      if (c.a < 0.12) continue;
      final hsl = HSLColor.fromColor(c);
      if (hsl.lightness > 0.96 || hsl.lightness < 0.05) continue;

      final sat = hsl.saturation;
      if (sat < 0.06) continue;

      final w = c.a * (0.35 + sat * 0.65);
      chromaticWeight += w;

      var bin = (hsl.hue / 360.0 * _hueBinCount).floor();
      if (bin >= _hueBinCount) bin = _hueBinCount - 1;
      weights[bin] += w;
      sumR[bin] += c.r * w;
      sumG[bin] += c.g * w;
      sumB[bin] += c.b * w;
    }

    if (chromaticWeight < 6) return null;

    var bestScore = 0.0;
    var bestBin = 0;
    for (var i = 0; i < _hueBinCount; i++) {
      final prev = weights[(i - 1 + _hueBinCount) % _hueBinCount];
      final score = prev + weights[i] + weights[(i + 1) % _hueBinCount];
      if (score > bestScore) {
        bestScore = score;
        bestBin = i;
      }
    }
    if (bestScore < 1.5) return null;

    var r = 0.0, g = 0.0, b = 0.0, wTotal = 0.0;
    for (var d = -1; d <= 1; d++) {
      final i = (bestBin + d + _hueBinCount) % _hueBinCount;
      wTotal += weights[i];
      r += sumR[i];
      g += sumG[i];
      b += sumB[i];
    }
    if (wTotal < 1e-6) return null;

    return Color.fromARGB(
      255,
      (r / wTotal * 255).round().clamp(0, 255),
      (g / wTotal * 255).round().clamp(0, 255),
      (b / wTotal * 255).round().clamp(0, 255),
    );
  }

  static Color? _alphaWeightedAverage(Iterable<Color> pixels) {
    var r = 0.0, g = 0.0, b = 0.0, n = 0.0;
    for (final c in pixels) {
      if (c.a < 0.12) continue;
      final hsl = HSLColor.fromColor(c);
      if (hsl.lightness > 0.97 || hsl.lightness < 0.04) continue;
      final w = c.a;
      r += c.r * w;
      g += c.g * w;
      b += c.b * w;
      n += w;
    }
    if (n < 4) return null;
    return Color.fromARGB(
      255,
      (r / n * 255).round().clamp(0, 255),
      (g / n * 255).round().clamp(0, 255),
      (b / n * 255).round().clamp(0, 255),
    );
  }

  static Color? _saturatedAverage(Iterable<Color> pixels) {
    var r = 0.0, g = 0.0, b = 0.0, n = 0;
    for (final c in pixels) {
      if (c.a < 0.12) continue;
      final hsl = HSLColor.fromColor(c);
      if (hsl.saturation < 0.03) continue;
      r += c.r;
      g += c.g;
      b += c.b;
      n++;
    }
    if (n < 4) return null;
    return Color.fromARGB(255, (r / n * 255).round(), (g / n * 255).round(), (b / n * 255).round());
  }
}
