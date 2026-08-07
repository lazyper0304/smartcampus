import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

import 'open_file.dart';

/// 跨平台 PDF 预览组件。
///
/// flutter_pdfview 仅支持 Android/iOS，Windows 等桌面端实例化
/// `PDFView` 会抛 `TargetPlatform.windows is not yet supported`。
/// 平台分发：
/// - **Android / iOS**：应用内 [PDFView] 渲染（翻页/缩放，原行为）；
/// - **Windows / Linux / macOS / Web**：显示引导占位 + 「用系统应用打开」
///   按钮（内部走 [openFileWithSystem]，Windows 用 ShellExecute 唤起
///   系统默认 PDF 查看器）。
class PlatformPdfView extends StatelessWidget {
  final String filePath;
  final ErrorCallback? onError;
  final PageErrorCallback? onPageError;
  final bool pageSnap;
  final FitPolicy? fitPolicy;

  const PlatformPdfView({
    super.key,
    required this.filePath,
    this.onError,
    this.onPageError,
    this.pageSnap = false,
    this.fitPolicy,
  });

  bool get _inAppSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  Widget build(BuildContext context) {
    if (_inAppSupported) {
      return PDFView(
        filePath: filePath,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling: true,
        pageSnap: pageSnap,
        fitPolicy: fitPolicy ?? FitPolicy.WIDTH,
        onError: onError,
        onPageError: onPageError,
      );
    }

    // 桌面端：应用内不支持，引导系统应用打开
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.picture_as_pdf_rounded,
            size: 48,
            color: isDark ? Colors.white38 : Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            '当前平台不支持应用内 PDF 预览',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => openFileWithSystem(context, filePath),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('用系统应用打开'),
          ),
        ],
      ),
    );
  }
}
