import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../core/http_client.dart';

/// 验证码识别服务
/// 参考 login-java ImageHelper + TesseractOCRHelper 实现
class CaptchaService {
  final SharedHttpClient client;

  CaptchaService(this.client);

  /// 检查是否需要验证码
  Future<bool> needsCaptcha(String host, String username) async {
    final resp = await client.get(
      Uri.parse('http://$host/authserver/needCaptcha.html'
          '?username=$username&pwdEncrypt2=pwdEncryptSalt'),
    );
    return resp.body.trim() == 'true';
  }

  /// 识别四位字母数字验证码，最多尝试 [maxTries] 次
  Future<String> recognize({
    required String captchaUrl,
    int maxTries = 10,
  }) async {
    for (int i = 0; i < maxTries; i++) {
      try {
        // 1. 下载验证码图片（原始字节）
        final bytes = await client.getBytes(Uri.parse(captchaUrl));

        // 2. 二值化预处理（参考 Java ImageHelper.binaryzation: 灰值阈值 115）
        final image = img.decodeImage(Uint8List.fromList(bytes));
        if (image == null) continue;

        final processed = _binaryzation(image, grayThreshold: 115);

        // 3. 保存到临时文件（ML Kit 需要文件路径或特定格式的 bytes）
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/captcha_$i.png');
        await tempFile.writeAsBytes(img.encodePng(processed));

        // 4. ML Kit OCR 识别
        final inputImage = InputImage.fromFilePath(tempFile.path);
        final recognizer = TextRecognizer();
        final result = await recognizer.processImage(inputImage);
        await recognizer.close();

        // 5. 清理临时文件
        try {
          await tempFile.delete();
        } catch (_) {}

        final text = result.text.replaceAll(RegExp(r'\s+'), '');
        if (_isValidCaptcha(text, 4)) {
          return text;
        }
      } catch (_) {
        // 重试
      }
    }
    throw Exception('验证码识别失败（已重试 $maxTries 次）');
  }

  /// 二值化：灰度阈值处理
  /// 参考 Java ImageHelper.binaryzation：grayValue=115, 公式 0.299*R + 0.578*G + 0.114*B
  img.Image _binaryzation(img.Image image, {int grayThreshold = 115}) {
    final result = img.Image.from(image);
    for (final pixel in result) {
      final r = pixel.r.toInt();
      final g = pixel.g.toInt();
      final b = pixel.b.toInt();
      final gray = (r * 0.299 + g * 0.578 + b * 0.114).toInt();
      if (gray >= grayThreshold) {
        pixel.setRgba(255, 255, 255, 255); // 白
      } else {
        pixel.setRgba(0, 0, 0, 255); // 黑
      }
    }
    return result;
  }

  /// 校验验证码格式：4 位字母数字
  bool _isValidCaptcha(String text, int expectedLen) {
    if (text.length != expectedLen) return false;
    return RegExp(r'^[a-zA-Z0-9]+$').hasMatch(text);
  }
}
